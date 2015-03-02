#!/usr/bin/env python
"""
Usage:
    test-looper-ctl list (revisions | workers | images)
    test-looper-ctl add (revisions <revision>... | workers [--total-price <price>])
    test-looper-ctl set (revisions <revision>... | image <image>)
    test-looper-ctl stop (all | <worker>...) [-i <keyfile>]
    test-looper-ctl start (all | <worker>...) [-i <keyfile>]
    test-looper-ctl restart (all | <worker>...) [-i <keyfile>]
    test-looper-ctl reboot (all | <worker>)
    test-looper-ctl terminate (all | <worker>...)
    test-looper-ctl run <command> (all | <worker>...) [-i <keyfile>] [--sequentially]
    test-looper-ctl launch image [--image-id <image>] [--instance-type <type>]
    test-looper-ctl create image [--image-id <image>] [--instance-type <type>] [-i <keyfile>]
    test-looper-ctl save image <instance> [--terminate-after-save]

Options:
    --total-price <price>       The total $ amount to spend on new workers. [Default: 1.0]
    --image-id <image>          The ID of the image to use. Defaults to the current test-looper image.
    --instance-type <type>      The EC2 instance type to use. [Default: t1.micro]
    --instance-id <instance>    The EC2 instance whose image is to be saved.
                                Defaults to the last instance started with the 'test-looper-ctl.py launch image' command.
    --terminate-after-save      Terminate the instance after saving its image. If this option is not
                                specified, the instance is stopped but not terminated.
    --sequentially              Run the commands one at a time instead of in parallel.
    -i <keyfile> --keyfile <keyfile>   The ssh private key file to use when connecting to remotes machines.

Revisions:
    test-looper keeps a list of git revisions that represent the set of commits it should test.
    Revisions are described with the same syntax used by 'git rev-list'.
    For example, the commits in the remote 'origin' in branch 'new_work' that are not in branch
    'base_line' are described as 'origin/new_work ^origin/base_line'.

    Commands:
        list    Prints out the current set of revisions used by test-looper.

        add     Add one or more git refs to the set of tested revisions.
                Example:
                    test-looper-ctl.py add revisions origin/my_branch origin/other_branch

                    This command adds the two revisions (origin/my_branch and origin/other_branch)
                    to the set of revisions tested by test-looper.

        set     Replaces the current set of revisions with a new set.
                Example:
                    test-looper-ctl.py set revisions origin/my_branch ^origin/my_branch^^^^^

                    This command discards the current set of revisions and replaces it with the
                    top 5 commits in the branch origin/my_branch.

Workers:
    This group of commands manages test-looper instances running in EC2.

    Commands:
        list        Prints out the set of active test-looper instances.

        add         Launches new test-looper instances.
                    EC2 spot instances are created to maximize the number of workers under a fixed
                    hourly price.
                    The price can be specified using the '--total-price' option. The default price
                    is $1.0/hour.

                    Example:
                        test-looper-ctl.py add workers --total-price 1.25

                        This command will create as many test-looper spot instances as possible with a
                        total cost of $1.25/hour.

                    Note: This command DOES NOT replace or terminate test-looper instances that are
                        already running. Running the example above twice in a row will create two
                        sets of instances, each costing $1.25/hour.

        stop        Stops the test-looper service on the specified workers.
                    Note: This command DOES NOT stop or terminate EC2 instances.

                    Examples:
                        1. test-looper-ctl.py stop all
                        2. test-looper-ctl.py stop i-fe470a96a i-0dc9c96f

        start       Starts the test-looper service on the specified workers.

        restart     Stops and starts the test-looper service on the specified workers.

        terminate   Cancels spot instance requests for the specified workers and terminates
                    running instances.

        run         Runs the specified shell command on a set of test-looper instances, and prints
                    the command's outputs from each instance.

                    Examples:
                        1. test-looper-ctl.py run "sudo apt-get install gcc-4.8 -y" all
                        2. test-looper-ctl.py run "rm -rf /mnt/data/backup" i-ed999185 i-4a2f422f

Images:
    This group of commands is used to create and manage the EC2 images (AMIs) used by test-looper.

    Commands:
        list        Prints out the set of available test-looper images.
                    The current image has an asterisk ('*') next to its ID.

        set         Marks the sprcified image as the current test-looper image.
                    Note: This command DOES NOT stop or relaunch running workers.
                          To switch workers to a new image, use the following steps:
                            1. test-looper-ctl.py set image ami-3fa27b7f
                            2. test-looper-ctl.py terminate all
                            3. test-looper-ctl.py add workers

        launch      Launches a new normal EC2 instance (not a spot request) with the specified
                    image and instance type.
                    This is useful for creating a new test-looper image based on an existing one.
                    If no image is specified, the current test-looper image is used.

                    Example:
                        test-looper-ctl.py launch image --instance-type m1.small

                        This command launches a new m1.small instance with the current test-looper
                        image.

        save        Creates a new test-looper image from a running instance.
                    If an instance ID is not specified, the last instance launched with
                    test-loopoer-ctl.py is used.
                    To terminate the instance after saving an image add the --terminate-after-save
                    switch.
"""
import boto
import docopt
import itertools
import time
import dateutil.parser
import dateutil
import datetime
import sys

import src.sshClient as sshClient
import ufora.core.SubprocessRunner as SubprocessRunner
import ufora.test.TestLooperRedisConnection as TestLooperRedisConnection
import src.TestLooperEc2Connection as TestLooperEc2Connection

verbs = ['list', 'set', 'add', 'stop', 'start', 'restart', 'run', 'reboot', \
         'terminate', 'launch', 'save', 'create']

multiple_images_with_current_tag_error_message = \
    "Error: More than image is marked as 'current'. " + \
    "Set a current image first by running 'test-looper-ctl.py set image <image>'."
no_image_with_current_tag_error_message = \
    "Error: No image is marked as 'current'. " + \
    "Set a current image first by running 'test-looper-ctl.py set image <image>'."

class TimeoutException(Exception):
    pass

class Revisions(object):
    def __init__(self, revlist=None):
        super(Revisions, self).__init__()

        self.revlist = revlist
        self.commitRange = \
                TestLooperRedisConnection.RedisConnection(db=1).redis.get('commitsToDeepTest') or ''

    def list(self):
        print "Revisions under test: %s\n" % self.commitRange


    def set(self):
        revs = ' '.join(self.revlist)
        print "Setting revision list to:\n\t%s\n" % revs

        commits = SubprocessRunner.callAndReturnOutput(
                    ['git', 'log', '--oneline', '--decorate'] + self.revlist
                    )
        print "test-looper will now run on the following commits:\n", commits
        TestLooperRedisConnection.RedisConnection(db=1).redis.set('commitsToDeepTest', revs)
        self.commitRange = revs

    def add(self):
        self.revlist = self.commitRange.split(' ') + self.revlist
        self.set()




class Workers(object):
    def __init__(self, workers=None, command=None, price=None, sshKeyFile=None, sequentially=None):
        super(Workers, self).__init__()
        self.ec2 = TestLooperEc2Connection.EC2Connection()
        self.workers = workers
        self.command = command
        self.price = price
        self.sshClient = sshClient.SshClient(sshKeyFile, sequentially)


    def list(self):
        instances = self.ec2.getLooperInstances()
        spotRequests = self.ec2.getLooperSpotRequests()
        self.printWorkerHeaders()
        for i, instance in enumerate(instances):
            instanceData = {
                    'ordinal': i + 1,
                    'id': instance.id,
                    'state': instance.state,
                    'image_id': instance.image_id,
                    'spotRequestId': instance.spot_instance_request_id,
                    'maxPrice': "    -    ",
                    'public_dns_name': instance.public_dns_name,
                    'launch_time': instance.launch_time
                    }
            if instance.spot_instance_request_id is not None:
                if instance.spot_instance_request_id in spotRequests:
                    instanceData['maxPrice'] = "%9.4f" % spotRequests[instance.spot_instance_request_id].price
                else:
                    instanceData['spotRequestId'] = "*" + instanceData['spotRequestId']
            self.printInstance(instanceData)
        print ""


    def add(self):
        currentImages = self.ec2.getCurrentLooperImage()
        if len(currentImages) > 1:
            print multiple_images_with_current_tag_error_message
            return

        ami = currentImages[0].id
        provisioned = 0.0
        while True:
            provisioned += 1
            max_bid = self.price / provisioned
            if max_bid < 0.025:
                break
            self.ec2.requestLooperInstances(ami, max_bid)
        print "Created %d spot requests" % provisioned


    def terminate(self):
        spotRequests = self.ec2.getLooperSpotRequests(includeInactive=True)
        instanceIds = [r.instance_id for r in spotRequests.itervalues() if r.state == 'active']

        if len(spotRequests) > 0:
            cancelledRequests = set([r.id for i in self.ec2.cancelSpotRequests(spotRequests.keys())])
            print "Cancelled %d of %d spot instance requeusts" % (len(cancelledRequests), len(spotRequests))
            leftovers = set(spotRequests.iterkeys()) - cancelledRequests
            if len(leftovers):
                print "The following spot instance requests could not be canceled:", leftovers


        if len(instanceIds) > 0:
            terminatedInstances = set([i.id for i in self.ec2.terminateInstances(instanceIds) if i.id])
            print "Terminating %d of %d active instances" % (len(terminatedInstances), len(instanceIds))
            leftovers = set(instanceIds) - terminatedInstances
            if len(leftovers):
                print "The following instances could not be terminated:", leftovers


    def stop(self):
        instances = self.ec2.getLooperInstances(self.workers)
        #if self.workers is not None and len(instances) < len(self.workers):
            #print "%d of the specified instances are not available. Do you want to contin
        print "%d loopers will be stopped." % len(instances)
        self.sshClient.runSsh(
            instances,
            "sudo stop test-looper; sudo projects/src/ufora/scripts/killexp python; sudo ps aux | grep python"
            )


    def start(self):
        instances = self.ec2.getLooperInstances(self.workers)
        #if self.workers is not None and len(instances) < len(self.workers):
            #print "%d of the specified instances are not available. Do you want to contin
        self.sshClient.runSsh(instances, "sudo start test-looper")

    def reboot(self):
        instances = self.ec2.getLooperInstances(self.workers)
        print "%d loopers will be rebooted." % len(instances)
        for i in instances:
            print 'rebooting %s %s' % (i.id, i.public_dns_name)
            i.reboot()

    def restart(self):
        self.stop()
        self.start()


    def run(self):
        instances = self.ec2.getLooperInstances(self.workers)
        self.sshClient.runSsh(instances, self.command)


    def printWorkerHeaders(self):
        print "\n        id      |    state   |     image    | spot request  | max price " + \
            "|          public dns name                           | uptime"
        print "=" * 151


    def printInstance(self, instance):
        print "%3d. %10s | %10s | %12s | %13s | %s | %50s | %s " % \
                (instance['ordinal'], instance['id'], instance['state'], instance['image_id'],
                 instance['spotRequestId'], instance['maxPrice'], instance['public_dns_name'],
                 str(datetime.datetime.utcnow() - dateutil.parser.parse(instance['launch_time']).replace(tzinfo=None))
                 )






def getCommand(args):
    if args['revisions']:
        return Revisions(args['<revision>'])
    elif args['images'] or args['image']:
        image = args['<image>'] if args['<image>'] is not None else args['--image-id']
        return TestLooperEc2Connection.Images(
                image=image,
                instanceType=args['--instance-type'],
                instanceId=args['<instance>'],
                terminateAfterSave=args['--terminate-after-save'],
                sshKeyFile=args['--keyfile']
                )
    return Workers(
        workers=None if args['all'] else args['<worker>'],
        command=args['<command>'],
        price=float(args['--total-price']),
        sshKeyFile=args['--keyfile'],
        sequentially=args['--sequentially']
        )


def main(args):
    command = getCommand(args)
    for verb in verbs:
        if args[verb]:
            getattr(command, verb)()
            return
    print "Error: unrecognized command.\nRun 'test-loopoer-ctl.py --help' to see available commands."

if __name__ == "__main__":
    main(docopt.docopt(__doc__, version="0.1.0"))
