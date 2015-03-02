#!/bin/env python

import argparse
import boto

def main(args):
    # launch instance
    # wait for instance to be ready

    # copy (scp)  "install-worker-dependencies" script

    # run "install-worker-dependencies" script on instance

    # save image

    # terminate instance
    pass

if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description = "Create an AMI for a test-looper-worker"
        )
