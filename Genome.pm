package Genome;

use warnings;
use strict;

use UR;

# GSCApp removes our overrides to can/isa for Class::Autoloader.  Tell it to put them back.
use GSCApp;
App::DB->db_access_level('rw');
App::Init->_restore_isa_can_hooks();


UR::Context->create_subscription(
    method => "commit",
    callback => sub {
        if (UR::DBI->no_commit) {
            App::DB->no_commit(1);
        }
        (App::DB->sync_database && App::DB->commit)
            or die "Failed to commit changes to the DW!: " . App::DB->error_message
    },
); 

# DB::single is set to this value in many places, creating a source-embedded break-point
# set it to zero in the debugger to turn off the constant stopping...
$DB::stopper = 1;

UR::Object::Type->define(
    class_name => 'Genome',
    is => ['UR::Namespace'],
    english_name => 'genome',
);

1;
