import paramiko
import os
import threading

class SshClient(object):
    def __init__(self, sshKeyFile, sequentially):
        self.sshKeyFile = sshKeyFile
        self.sequentially = sequentially

    def getSshKeyFilesForHost(self, host, config):
        if self.sshKeyFile:
            return [self.sshKeyFile]
        else:
            options = config.lookup(host)
            if 'identityfile' in options:
                return [os.path.expanduser(o) for o in options['identityfile']]
        return []

    def getSshConfig(self):
        configfile = os.path.expanduser('~/.ssh/config')
        sshConfig = paramiko.SSHConfig()

        if os.path.exists(configfile):
            with open(configfile, 'r') as f:
                sshConfig.parse(f)
        return sshConfig

    def runSsh(self, instances, command):
        threads = []
        results = {}
        sshConfig = self.getSshConfig()

        for instance in sorted(instances, key=lambda i: i.public_dns_name):
            print instance, instance.public_dns_name

        for instance in sorted(instances, key=lambda i: i.public_dns_name):
            def execute(dnsName):
                ssh = paramiko.SSHClient()
                ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
                sshKeys = self.getSshKeyFilesForHost(dnsName, sshConfig)
                for key in sshKeys:
                    try:
                        ssh.connect(dnsName, username='ubuntu', key_filename=key)
                    except paramiko.AuthenticationException:
                        continue

                    try:
                        stdin, stdout, stderr = ssh.exec_command(command)
                        results[dnsName] = "".join(stdout.readlines() + stderr.readlines())
                    finally:
                        ssh.close()

            thread = threading.Thread(target=execute, args=(instance.public_dns_name,))
            threads.append((instance.public_dns_name, thread))

        if not self.sequentially:
            for dns, t in threads:
                t.start()

        got = 0
        for dns, t in threads:
            if self.sequentially:
                t.start()
            t.join()
            print "received ", got, " / ", len(threads), " from ", dns
            got += 1

            print '*******************'
            print results[dns], '\n\n'
