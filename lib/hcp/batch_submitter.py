#!/usr/bin/env python3

"""
batch_submitter.py: Abstract base class for an object that submits batches of
pipeline processing jobs.
"""

# import of built-in modules
import os
import abc
import random

# import of third party modules
pass

# import of local modules
pass

# authorship information
__author__ = "Timothy B. Brown"
__copyright__ = "Copyright 2016, The Human Connectome Project"
__maintainer__ = "Timothy B. Brown"


def _inform(msg):
    """Inform the user by writing out a message that is prefixed by the module's file name."""
    print(os.path.basename(__file__) + ": " + msg)


def _debug(msg):
    #debug_msg = "DEBUG: " + msg
    #_inform(debug_msg)
    pass

class BatchSubmitter(abc.ABC):
    """This class is an abstract base class for classes that are used to submit jobs for one
    pipeline for a batch of subjects.
    """

    @property
    def START_SHADOW_NUMBER(self):
        """Starting ConnectomeDB shadow server number."""
        return 1


    @property
    def MAX_SHADOW_NUMBER(self):
        """Maximum ConnectomeDB shadow server number."""
        return 8


    def __init__(self, archive):
        """Construct a BatchSubmitter"""
        self._archive = archive
        self._current_shadow_number = random.randint(self.START_SHADOW_NUMBER, self.MAX_SHADOW_NUMBER)


    @property
    def shadow_number(self):
        """shadow number"""
        return self._current_shadow_number


    def increment_shadow_number(self):
        """Increments the current shadow number and cycles it around if it goes pass the maximum."""
        _debug("increment_shadow_number: orig current_shadow_number: " + str(self._current_shadow_number))
        self._current_shadow_number = self._current_shadow_number + 1
        if self._current_shadow_number > self.MAX_SHADOW_NUMBER:
            self._current_shadow_number = self.START_SHADOW_NUMBER
        _debug("increment_shadow_number: new current_shadow_number: " + str(self._current_shadow_number))


    def get_and_inc_shadow_number(self):
        current = self.shadow_number
        self.increment_shadow_number()
        return current


    @abc.abstractmethod
    def submit_jobs(self, subject_list):
        """Submit a batch of jobs for the specified subject list."""
        _inform("ERROR: Calling abstract method submit_jobs")
        pass

