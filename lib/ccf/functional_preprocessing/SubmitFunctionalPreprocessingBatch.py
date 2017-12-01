#!/usr/bin/env python3

# import of built-in modules
import logging

# import of third-party modules

# import of local modules
import ccf.archive as ccf_archive
import ccf.batch_submitter as batch_submitter
import ccf.functional_preprocessing.one_subject_job_submitter as one_subject_job_submitter
import ccf.functional_preprocessing.one_subject_run_status_checker as one_subject_run_status_checker
import ccf.subject as ccf_subject
import utils.file_utils as file_utils
import utils.my_configparser as my_configparser
import utils.os_utils as os_utils
import utils.user_utils as user_utils

# authorship information
__author__ = "Timothy B. Brown"
__copyright__ = "Copyright 2017, The Human Connectome Project/Connectome Coordination Facility"
__maintainer__ = "Timothy B. Brown"

# configure logging and create a module logger
module_logger = logging.getLogger(file_utils.get_logger_name(__file__))
# Note: The following can be overridden by file configuration
module_logger.setLevel(logging.WARNING)


class BatchSubmitter(batch_submitter.BatchSubmitter):

    def __init__(self):
        super().__init__(ccf_archive.CcfArchive())

    def submit_jobs(self, username, password, subject_list, config):
        """Submit functional preprocessing jobs for the listed subjects.

        Args:
            username (str): XNAT database username
            password (str): XNAT database password
            subject_list (sequence) CCF subjects
            config: (MyConfigParser) for retrieving processing configuration
                attributes

        """

        # create status checker and job submitter for one subject
        run_status_checker = one_subject_run_status_checker.OneSubjectRunStatusChecker()

        submitter = one_subject_job_submitter.OneSubjectJobSubmitter(
            self._archive, self._archive.build_home)
        
        # submit jobs for the listed subject scans
        for subject in subject_list:

            if self.check_already_queued(subject, run_status_checker):
                continue
            
            put_server = 'http://intradb-shadow'
            put_server += str(self.get_and_inc_shadow_number())
            put_server += '.nrg.mir:8080'
            
            # get information for the subject/scan from the configuration
            clean_output_first = config.get_bool_value(subject.subject_id, 'CleanOutputFirst')
            processing_stage_str = config.get_value(subject.subject_id, 'ProcessingStage')
            processing_stage = submitter.processing_stage_from_string(processing_stage_str)
            walltime_limit_hrs = config.get_value(subject.subject_id, 'WalltimeLimitHours')
            vmem_limit_gbs = config.get_value(subject.subject_id, 'VmemLimitGbs')
            output_resource_suffix = config.get_value(subject.subject_id, 'OutputResourceSuffix')

            print("-----")
            print("\tSubmitting", submitter.PIPELINE_NAME, "jobs for:")
            print("\t               project:", subject.project)
            print("\t               subject:", subject.subject_id)
            print("\t                  scan:", subject.extra)
            print("\t    session classifier:", subject.classifier)
            print("\t            put_server:", put_server)
            print("\t    clean_output_first:", clean_output_first)
            print("\t      processing_stage:", processing_stage)
            print("\t    walltime_limit_hrs:", walltime_limit_hrs)
            print("\t        vmem_limit_gbs:", vmem_limit_gbs)
            print("\toutput_resource_suffix:", output_resource_suffix)

            # configure one subject submitter

            # user and server information
            submitter.username = username
            submitter.password = password
            submitter.server = 'https://' + os_utils.getenv_required('XNAT_PBS_JOBS_XNAT_SERVER')

            # subject and project information
            submitter.project = subject.project
            submitter.subject = subject.subject_id
            submitter.classifier = subject.classifier
            submitter.session = subject.subject_id + '_' + subject.classifier
            submitter.scan = subject.extra

            # job parameters
            submitter.clean_output_resource_first = clean_output_first
            submitter.put_server = put_server
            submitter.walltime_limit_hours = walltime_limit_hrs
            submitter.vmem_limit_gbs = vmem_limit_gbs
            submitter.output_resource_suffix = output_resource_suffix

            # submit jobs
            submitted_job_list = submitter.submit_jobs(processing_stage)

            for job in submitted_job_list:
                print("\tsubmitted jobs:", job)

            print("-----")

            
def do_submissions(userid, password, subject_list):

    # read the configuration file
    config_file_name = file_utils.get_config_file_name(__file__)
    print("Reading configuration from file: " + config_file_name)
    config = my_configparser.MyConfigParser()
    config.read(config_file_name)
    
    # process the subjects in the list
    batch_submitter = BatchSubmitter()
    batch_submitter.submit_jobs(userid, password, subject_list, config)


if __name__ == '__main__':

    logging.config.fileConfig(
        file_utils.get_logging_config_file_name(__file__),
        disable_existing_loggers=False)

    # get Database credentials
    xnat_server = os_utils.getenv_required('XNAT_PBS_JOBS_XNAT_SERVER')
    userid, password = user_utils.get_credentials(xnat_server)

    # get list of subjects to process
    subject_file_name = file_utils.get_subjects_file_name(__file__)
    print("Retrieving subject list from: " + subject_file_name)
    subject_list = ccf_subject.read_subject_info_list(subject_file_name, separator=":")

    do_submissions(userid, password, subject_list)

    
