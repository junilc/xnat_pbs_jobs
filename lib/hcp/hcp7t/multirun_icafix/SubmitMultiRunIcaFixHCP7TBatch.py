#!/usr/bin/env python3

# import of built-in modules
import getpass
import logging

# import of third-party modules

# import of local modules
import ccf.batch_submitter as batch_submitter
import hcp.hcp7t.archive as hcp7t_archive
import hcp.hcp7t.multirun_icafix.one_subject_job_submitter as one_subject_job_submitter
import hcp.hcp7t.multirun_icafix.one_subject_run_status_checker as one_subject_run_status_checker
import hcp.hcp7t.subject as hcp7t_subject
import utils.file_utils as file_utils
import utils.my_configparser as my_configparser
import utils.os_utils as os_utils

# authorship information
__author__ = "Timothy B. Brown"
__copyright__ = "Copyright 2017, The Human Connectome Project/Connectome Coordination Facility"
__maintainer__ = "Timothy B. Brown"

# configure logging and create a module logger
module_logger = logging.getLogger(file_utils.get_logger_name(__file__))
# Note: This can be overridden by file configuration
module_logger.setLevel(logging.WARNING)  


class BatchSubmitter(batch_submitter.BatchSubmitter):

    def __init__(self):
        super().__init__(hcp7t_archive.Hcp7T_Archive())

    def submit_jobs(self, username, password, subject_list, config):

        # submit jobs for the listed subjects
        for subject in subject_list:

            run_status_checker = one_subject_run_status_checker.OneSubjectRunStatusChecker()
            if run_status_checker.get_queued_or_running(subject):
                print("-----")
                print("\t  NOT SUBMITTING JOBS FOR")
                print("\t                project: " + subject.project)
                print("\t                subject: " + subject.subject_id)
                print("\t                  extra: " + subject.extra)
                print("\t structural ref project: " + subject.structural_reference_project)
                print("\t JOBS ARE ALREADY QUEUED OR RUNNING")
                continue
            
            submitter = one_subject_job_submitter.OneSubjectJobSubmitter(
                self._archive, self._archive.build_home)

            put_server = 'http://db-shadow' + str(self.get_and_inc_shadow_number()) + '.nrg.mir:8080'

            # get information for the subject from the configuration
            clean_output_first = config.get_bool_value(subject.subject_id, 'CleanOutputFirst')
            processing_stage_str = config.get_value(subject.subject_id, 'ProcessingStage')
            processing_stage = submitter.processing_stage_from_string(processing_stage_str)
            walltime_limit_hrs = config.get_value(subject.subject_id, 'WalltimeLimitHours')
            mem_limit_gbs = config.get_value(subject.subject_id, 'MemLimitGbs')
            vmem_limit_gbs = config.get_value(subject.subject_id, 'VmemLimitGbs')
            output_resource_suffix = config.get_value(subject.subject_id, 'OutputResourceSuffix')

            print("-----")
            print("\tSubmitting", submitter.PIPELINE_NAME, "jobs for:")
            print("\t                project:", subject.project)
            print("\t      reference project:", subject.structural_reference_project)
            print("\t                subject:", subject.subject_id)
            print("\t                  extra:", subject.extra)
            print("\t structural ref project:", subject.structural_reference_project)
            print("\t             put_server:", put_server)
            print("\t     clean_output_first:", clean_output_first)
            print("\t       processing_stage:", processing_stage)
            print("\t     walltime_limit_hrs:", walltime_limit_hrs)
            print("\t          mem_limit_gbs:", mem_limit_gbs)
            print("\t         vmem_limit_gbs:", vmem_limit_gbs)
            print("\t output_resource_suffix:", output_resource_suffix)

            # user and server information
            submitter.username = username
            submitter.password = password
            submitter.server = 'https://' + os_utils.getenv_required('XNAT_PBS_JOBS_XNAT_SERVER')

            # subject and project information
            submitter.project = subject.project
            submitter.structural_reference_project = subject.structural_reference_project
            submitter.subject = subject.subject_id
            submitter.session = subject.subject_id + '_7T'
            submitter.classifier = '7T'

            # job parameters
            submitter.clean_output_resource_first = clean_output_first
            submitter.put_server = put_server
            submitter.walltime_limit_hours = walltime_limit_hrs
            submitter.mem_limit_gbs = mem_limit_gbs
            submitter.vmem_limit_gbs = vmem_limit_gbs
            submitter.output_resource_suffix = output_resource_suffix

            # submit jobs
            submitted_job_list = submitter.submit_jobs(processing_stage)

            for job in submitted_job_list:
                print("\tsubmitted jobs: ", str(job))

            print("-----")

def do_submissions(userid, password, subject_list):

    # read the configuration file
    config_file_name = file_utils.get_config_file_name(__file__)
    print("Reading configuration from file: " + config_file_name)
    config = my_configparser.MyConfigParser()
    config.read(config_file_name)

    # process subjects in the list
    batch_submitter = BatchSubmitter()
    batch_submitter.submit_jobs(userid, password, subject_list, config)


if __name__ == '__main__':

    logging_config_file_name = file_utils.get_logging_config_file_name(__file__)
    print("Reading logging configuration from file: " + logging_config_file_name)
    logging.config.fileConfig(logging_config_file_name, disable_existing_loggers=False)

    # get Database credentials
    userid = input("DB Username: ")
    password = getpass.getpass("DB Password: ")

    # get list of subjects to process
    subject_file_name = file_utils.get_subjects_file_name(__file__)
    print("Retrieving subject list from: " + subject_file_name)
    subject_list = hcp7t_subject.read_subject_info_list(subject_file_name, separator=":")

    do_submissions(userid, password, subject_list)
    
