# file: reader.pyx
"""
Reader class.

Implements reading header and data from an existing PSRDada ringbuffer.
"""

from cpython.buffer cimport PyBUF_READ
cimport dada_hdu
from .ringbuffer cimport Ringbuffer

import re
from .exceptions import PSRDadaError
from .ringbuffer import Ringbuffer

cdef extern from "<Python.h>":
    ctypedef struct PyObject:
        pass
    PyObject *PyMemoryView_FromMemory(char *mem, Py_ssize_t size, int flags)

cdef class Reader(Ringbuffer):
    """
    Reader class.

    Implements reading header and data from and existing PSRDada ringbuffer.
    Extends the Ringbuffer class.
    """
    def connect(self, key):
        """Connect to a PSR DADA ringbuffer with the specified key, and lock it for reading"""
        super().connect(key)

        if dada_hdu.dada_hdu_lock_read(self._c_dada_hdu) < 0:
            raise PSRDadaError("ERROR in dada_hdu_lock_read")

    def disconnect(self):
        """Disconnect from PRS DADA ringbuffer"""

        # if we are still holding a page, mark it cleared
        cdef dada_hdu.ipcbuf_t *ipcbuf = <dada_hdu.ipcbuf_t *> self._c_dada_hdu.data_block
        if self.isHoldingPage:
            dada_hdu.ipcbuf_mark_cleared (ipcbuf)
            self.isHoldingPage = False

        dada_hdu.dada_hdu_unlock_read(self._c_dada_hdu)

        super().disconnect()

    def getHeader(self):
        """Read header from the Ringbuffer"""
        # read and parse the header
        cdef dada_hdu.uint64_t bufsz
        cdef char * c_string = NULL

        c_string = dada_hdu.ipcbuf_get_next_read (self._c_dada_hdu.header_block, &bufsz)
        py_string = c_string[:bufsz].decode('ascii')

        dada_hdu.ipcbuf_mark_cleared (self._c_dada_hdu.header_block)

        # split lines on newline and backslash
        lines = re.split('\n|\\\\', py_string)

        for line in lines:
            # split key value on tab and space
            keyvalue = line.replace('\t', ' ').split(' ', 1)
            if len(keyvalue) == 2:
                self.header[keyvalue[0]] = keyvalue[1]

        return self.header

    def getNextPage(self):
        """Return a memoryview on the next available ringbuffer page"""

        if self.isHoldingPage:
            raise PSRDadaError("Error in getNextPage: previous page not cleared.")

        cdef char * c_page = dada_hdu.ipcbuf_get_next_read (<dada_hdu.ipcbuf_t *> self._c_dada_hdu.data_block, &self._bufsz)
        self.isHoldingPage = True

        return <object> PyMemoryView_FromMemory(c_page, self._bufsz, PyBUF_READ)

    def markCleared(self):
        if self.isHoldingPage:
            dada_hdu.ipcbuf_mark_cleared (<dada_hdu.ipcbuf_t *> self._c_dada_hdu.data_block)

        self.isHoldingPage = False
        self.isEndOfData = dada_hdu.ipcbuf_eod (<dada_hdu.ipcbuf_t *> self._c_dada_hdu.data_block)

    def __iter__(self):
        return self

    def __next__(self):
        self.markCleared()

        if self.isEndOfData:
            raise StopIteration

        return self.getNextPage()
