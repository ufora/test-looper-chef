#!/bin/env python

import argparse
import sys

def main(args):

    return 0

if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description="Initialize a test-looper worker instance on first boot"
        )

    parser.add_argument("--server", help="Address/hostname of test-looper-server")
    parser.add_argument("--branch", help="Branch name in the test-looper repo")
    sys.exit(main(parser.parse_args()))

