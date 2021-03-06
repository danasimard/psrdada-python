#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
PSRDada header test.

Tests for handling header data using the Reader and Writer classess from
the `psrdada` module.
"""

import sys
import os
import unittest

from psrdada import Reader
from psrdada import Writer

HEADER_TEST_DATA = {
    'hello': 'world',
    'PSRDada': 'testsuite'
}


class TestReadWriteHeader(unittest.TestCase):
    """
    Test for reading and writing header data.

    Start a ringbuffer instance and write some data to the header block,
    then read it back.
    """

    def setUp(self):
        """Test setup."""
        os.system("dada_db -d 2> /dev/null ; dada_db -k dada")

        self.writer = Writer()
        self.writer.connect(0xdada)

        self.reader = Reader()
        self.reader.connect(0xdada)

    def tearDown(self):
        """Test teardown."""
        self.writer.disconnect()
        self.reader.disconnect()

        os.system("dada_db -d -k dada 2> /dev/null")

    def test_writing_header(self):
        """
        Header reading and writing test.

        Read a previously written header from the ringbuffer,
        and test if the headers are equal.
        """
        self.writer.setHeader(HEADER_TEST_DATA)
        header = self.reader.getHeader()

        del header['__RAW_HEADER__']
        self.assertDictEqual(header, HEADER_TEST_DATA)


if __name__ == '__main__':
    sys.exit(unittest.main())
