""" Module for Manta client wrapper and related tooling. """
import logging
import os
from manager.utils import debug, env, to_flag

# pylint: disable=import-error,dangerous-default-value,invalid-name
import boto3
import botocore

loglevel = logging.getLevelName(os.environ.get('LOG_LEVEL_BOTO', 'INFO'))
boto3.set_stream_logger('boto3', loglevel)

class Manta(object):
    """
    The Manta class wraps access to the Manta object store, where we'll put
    our MySQL backups.
    """
    def __init__(self, envs=os.environ):
        self.bucket_name = env('AWS_S3_BUCKET', None, envs)
        self.endpoint = env('AWS_S3_ENDPOINT', 'https://s3.cloud.syseleven.net', envs)
        self.access = env('AWS_ACCESS_KEY_ID', None, envs)
        self.secret = env('AWS_SECRET_ACCESS_KEY', None, envs)

        assert self.bucket_name, "missing bucket"
        assert self.endpoint, "missing endpoint"
        assert self.access, "missing access key"
        assert self.secret, "missing secret"

        self.s3 = boto3.resource('s3', endpoint_url = self.endpoint, config=botocore.client.Config(s3={'addressing_style': 'virtual'}))
        self.bucket = self.s3.Bucket(self.bucket_name)

    @debug
    def get_backup(self, backup_id):
        """ Download file from Manta, allowing exceptions to bubble up """
        try:
            os.mkdir('/tmp/backup', 0770)
        except OSError:
            pass
        self.bucket.download_file(backup_id, '/tmp/backup/{}'.format(backup_id))

    @debug 
    def exists(self, backup_id):
        try:
            self.s3.Object(self.bucket_name, backup_id).load()
            return True
        except botocore.exceptions.ClientError as e:
            if e.response['Error']['Code'] == "404":
                return False
            else:
                raise

    @debug
    def put_backup(self, backup_id, infile):
        """ Upload the backup file to the expected path """
        if not self.exists(backup_id):
            self.bucket.upload_file(infile, backup_id)
