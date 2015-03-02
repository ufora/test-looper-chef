#!/usr/bin/env python

import subprocess
import sys

def installDocker():
    subprocess.check_output("sudo apt-get update", shell=True)
    subprocess.check_output("sudo apt-get install -y docker.io", shell=True)

    # configure docker to run without root
    subprocess.check_output("sudo groupadd docker", shell=True)
    subprocess.check_output("sudo gpasswd -a ${USER} docker", shell=True)
    subprocess.check_output("sudo service docker.io restart", shell=True)

def installPythonModules():
    subprocess.check_output("sudo pip install boto")


def main():
    try:
        installDocker()
        installPythonModules()
    except subprocess.CalledProcessError as e:
        print "Command '%s' exited with status '%s':\n%s" % (
            e.cmd, e.returncode, e.output)
        return e.returncode

if __name__ == "__main__":
    sys.exit(main())