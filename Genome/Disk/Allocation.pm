package Genome::Disk::Allocation;

# Adaptor for GSC::DiskAllocation

# Do NOT use this module from anything in the GSC schema,
# though the converse will work just fine.

# This module will handle all PSE calls based on modifications

use strict;
use warnings;

class Genome::Disk::Allocation {
    table_name => "(select * from disk_allocation\@dw) disk_allocation",
    id_by => [
              allocator_id => {
                               is => 'Number',
                               doc => 'The id for the allocator event',
                           },
          ],
    has => [
            disk_group_name => {
                                  is => 'Text',
                                  doc => 'The name of the disk group',
                              },
            mount_path => {
                           is => 'Text',
                           doc => 'The mount path of the disk volume',
                       },
            allocation_path => {
                                is => 'Text',
                                doc => 'The sub-dir of the disk volume for which space is allocated',
                            },
            kilobytes_requested => {
                                    is => 'Number',
                                    doc => 'The disk space allocated in kilobytes',
                                },
            kilobytes_used => {
                               is => 'Number',
                               doc => 'The actual disk space used by owner',
                           },
            owner_class_name => {
                                 is => 'Text',
                                 doc => 'The class name for the owner of this allocation',
                             },
            owner_id => {
                         is => 'Number',
                         doc => 'The id for the owner of this allocation',
                         },
            group_subdirectory => {
                                   is => 'Text',
                                   doc => 'The group specific subdirectory where space is allocated',
            }
        ],
        has_optional => [
                         allocator => {
                                       calculate_from => 'allocator_id',
                                       calculate => q|
                                                     return GSC::PSE::AllocateDiskSpace->get($allocator_id);
                                       |,
                                       doc => 'The allocate disk space PSE',
                                   },
                     ],
        data_source => 'Genome::DataSource::GMSchema',
};

1;




