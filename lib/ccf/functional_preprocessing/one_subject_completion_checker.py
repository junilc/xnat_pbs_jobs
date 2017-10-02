#!/usr/bin/env python3

# import of built-in modules
import os
import sys

# import of third-party modules

# import of local modules
import ccf.archive as ccf_archive
import ccf.functional_preprocessing.one_subject_job_submitter as one_subject_job_submitter
import ccf.one_subject_completion_checker as one_subject_completion_checker
import ccf.subject as ccf_subject
import utils.my_argparse as my_argparse

# authorship information
__author__ = "Timothy B. Brown"
__copyright__ = "Copyright 2017, The Connectome Coordination Facility"
__maintainer__ = "Timothy B. Brown"


class OneSubjectCompletionChecker(one_subject_completion_checker.OneSubjectCompletionChecker):

    def __init__(self):
        super().__init__()

    @property
    def PIPELINE_NAME(self):
        return one_subject_job_submitter.OneSubjectJobSubmitter.MY_PIPELINE_NAME()

    def my_resource(self, archive, subject_info):
        return archive.functional_preproc_dir_full_path(subject_info)

    def my_prerequisite_dir_full_paths(self, archive, subject_info):
        dirs = []
        dirs.append(archive.structural_preproc_dir_full_path(subject_info))

    def completion_marker_file_name(self):
        return self.PIPELINE_NAME + '.XNAT_CHECK.success'

    def starttime_marker_file_name(self):
        return self.PIPELINE_NAME + '.starttime'

    def list_of_expected_files(self, archive, subject_info):

        l = []

        root_dir = os.sep.join([self.my_resource(archive, subject_info), subject_info.subject_id])
        
        # ...

        return l

    
if __name__ == "__main__":

    parser = my_argparse.MyArgumentParser(
        description="Program to check for completion of Functional Preprocessing.")

    # mandatory arguments
    parser.add_argument('-p', '--project', dest='project', required=True, type=str)
    parser.add_argument('-s', '--subject', dest='subject', required=True, type=str)
    parser.add_argument('-c', '--classifier', dest='classifier', required=True, type=str)
    parser.add_argument('-n', '--scan', dest='scan', required=True, type=str)

    # optional arguments
    parser.add_argument('-v', '--verbose', dest='verbose', action='store_true',
                        required=False, default=False)
    parser.add_argument('-o', '--output', dest='output', required=False, type=str)
    parser.add_argument('-a', '--check-all', dest='check_all', action='store_true',
                        required=False, default=False)

    # parse the command line arguments
    args = parser.parse_args()

    # check the specified subject and scan for functional preprocessing completion
    archive = ccf_archive.CcfArchive()
    subject_info = ccf_subject.SubjectInfo(
        project=args.project,
        subject_id=args.subject,
        classifier=args.classifier,
        extra=args.scan)
    completion_checker = OneSubjectCompletionChecker()

    if args.output:
        processing_output = open(args.output, 'w')
    else:
        processing_output = sys.stdout

    if completion_checker.is_processing_complete(
            archive=archive,
            subject_info=subject_info,
            verbose=args.verbose,
            output=processing_output,
            short_circuit=not args.check_all):
        print("Exiting with 0 code - Completion Check Successful")
        exit(0)
    else:
        print("Existing wih 1 code - Completion Check Unsuccessful")
        exit(1)


        
        
        
