import boto
import datetime
import itertools
import os
import sys
import time

import src.sshClient as sshClient

looper_security_group = 'looper'
image_builder_security_group = 'dev-security-group'

looper_image_name_prefix = 'test-looper-small'
image_builder_tag = 'test-looper-image-builder'
looper_spot_request_role = 'test-looper'
looper_current_image_tag = 'current'
looper_instance_profile_arn = 'arn:aws:iam::793532271015:instance-profile/test-looper'
all_states_except_terminated = ['pending', 'running', 'shutting-down', 'stopping', 'stopped']

install_worker_dependencies_file = "install-worker-dependencies.py"

class EC2Connection(object):
    def __init__(self):
        self.ec2 = boto.connect_ec2()


    def getLooperInstances(self, ids=None):
        reservations = self.getLooperReservations(ids)
        return list(itertools.chain(*[res.instances for res in reservations]))


    def getLooperReservations(self, ids=None):
        return self.ec2.get_all_instances(
            ids,
            {
                #'group-name': 'dev-security-group', #looper_security_group,
                'group-name': looper_security_group,
                'instance-state-name': all_states_except_terminated
            })


    def getLooperSpotRequests(self, includeInactive=False):
        def isLooperRequest(spotRequest):
            if len(filter(lambda g: g.name == 'looper', spotRequest.launch_specification.groups)) == 0:
                return False

            return True

        return {req.id : req for req in self.ec2.get_all_spot_instance_requests() if isLooperRequest(req)}


    def cancelSpotRequests(self, requestIds):
        spotRequests = self.ec2.get_all_spot_instance_requests(requestIds)
        instanceIds = [r.instance_id for r in spotRequests if r.state == 'active']
        self.ec2.cancel_spot_instance_requests(requestIds)
        self.terminateInstances(instanceIds)

    def currentSpotPrices(self, instanceType=None):
        now = datetime.datetime.fromtimestamp(time.time()).isoformat()
        prices = self.ec2.get_spot_price_history(
                            start_time=now,
                            end_time=now,
                            instance_type=instanceType
                            )
        pricesByZone = {}
        for p in prices:
            if p.availability_zone in pricesByZone:
                continue
            pricesByZone[p.availability_zone] = p.price
        return pricesByZone


    def terminateInstances(self, instanceIds):
        print "Terminating instances:", instanceIds
        return self.ec2.terminate_instances(instanceIds)


    def getLooperImages(self, ids=None, filters=None):
        allFilters = {'name': looper_image_name_prefix + '*'}
        if filters is not None:
            assert isinstance(filters, dict)
            allFilters.update(filters)
        return self.ec2.get_all_images(image_ids=ids, filters=allFilters)

    def saveImage(self, instanceId, namePrefix):
        name = self.makeImageName(namePrefix)
        return self.ec2.create_image(instanceId, name)

    def makeImageName(self, namePrefix):
        today = str(datetime.date.today())
        namePattern = "%s-%s*" % (namePrefix, today)
        existingImages = self.ec2.get_all_images(
                                            owners=['self'],
                                            filters={'name': namePattern}
                                            )
        if len(existingImages) == 0:
            name = namePattern[:-1]
        else:
            name = "%s-%s-%s" % (namePrefix, today, len(existingImages))
        return name

    def waitForImage(self, imageId, timeout=300):
        t0 = time.time()
        sys.stdout.write("Waiting for image %s" % imageId)
        sys.stdout.flush()
        try:
            while True:
                try:
                    images = self.getLooperImages(ids=[imageId])
                except boto.exception.EC2ResponseError:
                    images = []
                if len(images) == 1:
                    if images[0].state == u'available':
                        return
                    if images[0].state != u'pending':
                        print "Image is in unexpected state:", images[0].state
                        raise Exception("Unexpected image state")
                sys.stdout.write('.')
                sys.stdout.flush()
                time.sleep(2)
                if time.time() - t0 > timeout:
                    raise TimeoutException()
        finally:
            print("")


    def getCurrentLooperImage(self):
        return self.getLooperImages(filters={'tag-key': looper_current_image_tag})


    def requestLooperInstances(self, ami, max_bid, instance_type="m3.xlarge", user_data=None):
        self.ec2.request_spot_instances(
            price = max_bid,
            image_id = ami,
            user_data=user_data,
            security_groups=[looper_security_group],
            instance_type=instance_type,
            key_name="test_looper",
            type='persistent',
            instance_profile_arn=looper_instance_profile_arn
            )


    def startLooperInstance(self, ami, instanceType):
        reservation = self.ec2.run_instances(
                image_id=ami,
                instance_type=instanceType,
                key_name='test_looper',
                security_groups=[image_builder_security_group]
                )
        runningInstances = []
        for instance in reservation.instances:
            print "Launching new instance %s." % instance.id
            instance.add_tag(image_builder_tag)
            if instance.state == 'pending':
                print "New instance %s is in the 'pending' state. Waiting for it to start." % instance.id
            while instance.state == 'pending':
                time.sleep(5)
                instance.update()
            if instance.state != 'running':
                print "Error: New instance %s entered the %s state." % (instance.id, instance.state)
                return
            runningInstances.append(instance)
        return runningInstances

class Images(object):
    def __init__(self, image=None, instanceType=None, instanceId=None, 
                 terminateAfterSave=False, sshKeyFile=None, sequentially=None, 
                 setCurrent=False):
        self.ec2 = EC2Connection()
        self.image = image
        self.instanceType = instanceType
        self.instanceId = instanceId
        self.terminateAfterSave = terminateAfterSave
        self.sshClient = sshClient.SshClient(sshKeyFile, sequentially)
        self.setCurrent = setCurrent

    def list(self):
        images = sorted(
                self.ec2.getLooperImages(),
                key=lambda image: image.name,
                reverse=True
                )
        print "\n         id        |         name                     |    status "
        print "=" * 68
        for i, image in enumerate(images):
            imageId = image.id
            if 'current' in image.tags:
                imageId = "*" + imageId
            print "%3d. %13s | %s | %s" % (i+1, imageId, image.name.ljust(32), image.state)
        print ""


    def set(self):
        self.setImage(self.image)

    def setImage(self, imageId):
        try:
            newImage = self.ec2.getLooperImages(ids=[imageId])
            assert len(newImage) <= 1, "More than one image has ID %s!" % imageId
        except boto.exception.EC2ResponseError as e:
            print "Error: %s could not be retrieved. %s" % (imageId, e.error_message)
            return

        currentImages = self.ec2.getCurrentLooperImage()
        if len(currentImages) > 1:
            print "Warning: More than image is marked as 'current'"

        for image in currentImages:
            print "Removing 'current' tag from %s: %s" % (image.id, image.name)
            image.remove_tag('current')

        print "Setting 'current' tag on %s" % imageId
        newImage[0].add_tag('current')

    def launch(self):
        image = self.image
        if image is None:
            images = self.ec2.getCurrentLooperImage()
            print images
            if len(images) > 1:
                print multiple_images_with_current_tag_error_message
                return
            elif len(images) == 0:
                print no_image_with_current_tag_error_message
                return
            image = images[0].id

        print "Launching instance of type %s with image %s" % (self.instanceType, image)
        try:
            instances = self.ec2.startLooperInstance(image, self.instanceType)

            if instances is None:
                return
            print "New instance started at %s" % instances[0].public_dns_name
            return instances
        except boto.exception.EC2ResponseError as e:
            print "Error: cannot launch instance. %s" % e.error_message
            return

    def launchAndWait(self):
        instances = self.launch()
        assert len(instances) == 1
        instance = instances[0]

        self.waitForInstance(instance)
        return instance

    def waitForInstance(self, instance):
        self.waitUntilRunning(instance)
        self.waitUntilOkStatus(instance)

    def waitUntilRunning(self, instance, timeout=360):
        t0 = time.time()
        instanceId = instance.id
        sys.stdout.write("waiting for instance %s to run ..." % instanceId)
        sys.stdout.flush()
        while True:
            instances = [i for r in self.ec2.ec2.get_all_instances(
                instance_ids=[instanceId]) for i in r.instances]
            assert len(instances) == 1
            _instance = instances[0]
            if _instance.state == 'running':
                print "instance %s is running!" % instanceId
                return
            else:
                print 'waiting for instance to run ... ' + \
                    'current state: ', _instance.state
                time.sleep(2)
                if time.time() - t0 > timeout:
                    raise TimeoutException()
            

    def waitUntilOkStatus(self, instance, timeout=360):
        t0 = time.time()
        instanceId = instance.id
        sys.stdout.write(
            "waiting for instance %s " % instanceId + \
            " to have system and instance statuses 'ok' ..."
            )
        sys.stdout.flush()
        retryIx = 0
        while True:
            instanceStatuses = {
                s.id: s for s in self.ec2.ec2.get_all_instance_status(
                    instance_ids=[instanceId])
                }
            print "instanceStatuses = ", str(instanceStatuses)

            instanceStatus = instanceStatuses[instanceId]
            if instanceStatus.system_status.status == 'ok' and \
               instanceStatus.instance_status.status == 'ok':
                print "instance %s has 'ok' system and instance statuses" % instanceId
                return
            else:
                retryIx += 1
                print "retryIx = %s. " % retryIx + \
                    ". Waiting for (system_status, instance_status)" + \
                    " to both be 'ok' ... " + \
                    "current values: (%s, %s), respectively" % (
                        instanceStatus.system_status.status, 
                        instanceStatus.instance_status.status)
                time.sleep(2)
                if time.time() - t0 > timeout:
                    raise TimeoutException()

    def save(self):
        imageId = self.ec2.saveImage(self.instanceId, looper_image_name_prefix)
        print "Creating new image:", imageId
        try:
            self.ec2.waitForImage(imageId)
        except TimeoutException:
            print "Timeout exceeded waiting for image to be created."
            return
        self.setImage(imageId)
        if self.terminateAfterSave:
            self.ec2.terminateInstances([self.instanceId])

