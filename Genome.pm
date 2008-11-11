package Genome;

use warnings;
use strict;

use UR;

# GSCApp removes our overrides to can/isa for Class::Autoloader.  Tell it to put them back.
use GSCApp;
App::Init->_restore_isa_can_hooks();

# DB::single is set to this value in many places, creating a source-embedded break-point
# set it to zero in the debugger to turn off the constant stopping...
$DB::stopper = 1;

UR::Object::Type->define(
    class_name => 'Genome',
    is => ['UR::Namespace'],
    english_name => 'genome',
);

1;
