#!/gsc/bin/perl

use strict;
use warnings;

use Data::Dumper;
use above "Genome";
use Command;
use Test::More tests => 241;
use Test::Differences;
use File::Path;

$ENV{UR_DBI_NO_COMMIT} = 1;
$ENV{UR_USE_DUMMY_AUTOGENERATED_IDS} = 1;

my $default_subject_name = 'H_GV-933124G-skin1-9017g';
my $default_subject_type = 'sample_name';
my $default_pp_name = 'solexa_maq0_6_8';

like(Genome::Model::Command::Define->help_brief,qr/define/i,'help_brief test');
like(Genome::Model::Command::Define->help_synopsis, qr(genome model define),'help_synopsis test');
like(Genome::Model::Command::Define->help_detail,qr(^This defines a new genome model),'help_detail test');

my $tmp_dir = File::Temp::tempdir(CLEANUP => 1);

# test normal model and processing profile creation for reference alignment
test_model_from_params(
    model_params => {
        model_name              => "test_model_incomplete_data_dir_$ENV{USER}",
        subject_name            => $default_subject_name,
        subject_type            => $default_subject_type,
        processing_profile_name => $default_pp_name,
        data_directory          => $tmp_dir,
    },
);

test_model_from_params(
    model_params => {
        model_name              => "test_model_complete_data_dir_$ENV{USER}",
        subject_name            => $default_subject_name,
        subject_type            => $default_subject_type,
        processing_profile_name => $default_pp_name,
        data_directory          => $tmp_dir ."/test_model_complete_data_dir_$ENV{USER}",
    },
);


# test normal model and processing profile creation for reference alignment
test_model_from_params(
    model_params => {
        subject_name            => $default_subject_name,
        subject_type            => $default_subject_type,
        processing_profile_name => $default_pp_name,
    },
);

# test create for a genome model with defined model_name
test_model_from_params(
    model_params => {
        model_name              => "test_model_$ENV{USER}",
        subject_name            => $default_subject_name,
        subject_type            => $default_subject_type,
        processing_profile_name => $default_pp_name,
    },
);

# test create for a genome model with an incorrect subject_type
test_model_from_params(
    test_params => {
        fail => 'invalid_subject_type',
    },
    model_params => {
        subject_name => $default_subject_name,
        subject_type => 'invalid_subject_type',
        processing_profile_name   => $default_pp_name,
    },
);

# test create for a genome model with an incorrect subject_name
test_model_from_params(
    test_params => {
        fail => 'invalid_subject_name',
    },
    model_params => {
        subject_name => 'invalid_subject_name',
        subject_type => $default_subject_type,
        processing_profile_name   => $default_pp_name,
    },
);

# test create for a genome model with an incorrect subject_name
test_model_from_params(
    test_params => {
        fail => 'invalid_pp_name',
    },
    model_params => {
        subject_name => $default_subject_name,
        subject_type => $default_subject_type,
        processing_profile_name   => 'invalid_pp_name',
    },
);

# test when no processing profile name passed as arg
test_model_from_params(
    test_params => {
        fail => 'No value specified for required property processing_profile_name',
    },
    model_params => {
        subject_name => $default_subject_name,
        subject_type => $default_subject_type,
    },
);

# test when no subject name is passed as arg
test_model_from_params(
    test_params => {
        fail => 'No value specified for required property subject_name',
    },
    model_params => {
        subject_type => $default_subject_type,
        processing_profile_name   => $default_pp_name,
    },
);

# test when bare args empty array_ref is passed
test_model_from_params(
    model_params => {
        subject_name => $default_subject_name,
        subject_type => $default_subject_type,
        processing_profile_name   => $default_pp_name,
        bare_args => [],
    },
);

# test when a bogus_param gets passed in as bare args
test_model_from_params(
    test_params => {
        fail => 'bogus_param',
    },
    model_params => {
        subject_name => $default_subject_name,
        subject_type => $default_subject_type,
        processing_profile_name   => $default_pp_name,
        bare_args => [ 'bogus_param' ],
    },
);

# test create for a genome model micro array illumina
test_model_from_params(
    model_params => {
        subject_name => $default_subject_name,
        subject_type => $default_subject_type,
        processing_profile_name   => 'micro-array-illumina',
    },
);

# test create for a genome model micro array illumina
test_model_from_params(
    model_params => {
        subject_name => $default_subject_name,
        subject_type => $default_subject_type,
        processing_profile_name   => 'micro-array-affymetrix',
    },
);

# test create for a genome model assembly
test_model_from_params(
    model_params => {
        subject_name => $default_subject_name,
        subject_type => $default_subject_type,
        processing_profile_name   => '454_newbler_default_assembly',
    },
);

exit;

########################################################3

sub test_model_from_params {
    my %params = @_;
    my %test_params = %{$params{'test_params'}} if defined $params{'test_params'};

    my %model_params = %{$params{'model_params'}};
    if ($test_params{'fail'}) {
        &failed_create_model($test_params{'fail'},\%model_params);
    } else {
        &successful_create_model(\%model_params);
    }
}

sub successful_create_model {
    my $params = shift;
    my %params = %{$params};

    my $pp = Genome::ProcessingProfile->get(name => $params{processing_profile_name});
    isa_ok($pp,'Genome::ProcessingProfile');

    my $subclass = join('', map { ucfirst($_) } split('\s+',$pp->type_name));
    if (!$params{subject_name}) {
        $params{subject_name} = 'invalid_subject_name';
    }
    my $expected_model_name;
    if ($params{model_name}) {
        my $test_model_link_pathname = Genome::Model->model_links_directory . '/' . $params{'model_name'};
        symlink('/tmp/', $test_model_link_pathname);
        $expected_model_name = $params{model_name};
    } else {
        my $subject_name = Genome::Model::Command::Define->_sanitize_string_for_filesystem($params{subject_name});
        $expected_model_name = $subject_name .'.'. $params{processing_profile_name};
    }
    my $expected_data_directory;
    if ($params{data_directory}) {
        my $base_name = File::Basename::basename($params{data_directory});
        if ($expected_model_name eq $base_name) {
            $expected_data_directory = $params{data_directory};
        } else {
            $expected_data_directory = $params{data_directory} .'/'. $expected_model_name;
        }
    }
    my $expected_user_name = $ENV{USER};
    my $current_time = UR::Time->now;
    my ($expected_date) = split('\w',$current_time);
    
    my $create_command = Genome::Model::Command::Define::ReferenceAlignment->create(%params);
    isa_ok($create_command,'Genome::Model::Command::Define');

    $create_command->dump_error_messages(0);
    $create_command->dump_warning_messages(0);
    $create_command->dump_status_messages(0);
    $create_command->queue_error_messages(1);
    $create_command->queue_warning_messages(1);
    $create_command->queue_status_messages(1);

    ok($create_command->execute, 'create command execution successful');
    my @error_messages = $create_command->error_messages();
    my @warning_messages = $create_command->warning_messages();
    my @status_messages = $create_command->status_messages();
    ok(! scalar(@error_messages), 'no error messages');
    if ($params{'model_name'}) {
        ok(scalar(@warning_messages), 'create model generated a warning message');
        like($warning_messages[0], qr(model symlink.*already exists), 'Warning message complains about the model link already existing');
    } else {
        ok(!scalar(@warning_messages), 'no warning messages');
        if (@warning_messages) {
            print join("\n",@warning_messages);
        }
    }
    ok(scalar(@status_messages), 'There was a status message');

    like($status_messages[0], qr|Created model:|, 'First message is correct');
    # FIXME - some of those have a second message about creating a directory
    # should probably test for that too
    delete($params{data_directory});
    delete($params{bare_args});
    delete($params{model_name});
    my $model = Genome::Model->get(name => $expected_model_name,);
    isa_ok($model,'Genome::Model::'. $subclass);
    ok($model, 'creation worked for '. $expected_model_name .' model');
    is($model->name,$expected_model_name,'model model_name accessor');
    for my $property_name (keys %params) {
        is($model->$property_name,$params{$property_name},$property_name .' model indirect accessor');
    }
    is($model->user_name,$expected_user_name,'model user_name accesssor');
    like($model->creation_date,qr/$expected_date/,'model creation_date accessor');
    is($model->processing_profile_id,$pp->id,'model processing_profile_id indirect accessor');
    is($model->type_name,$pp->type_name,'model type_name indirect accessor');
  SKIP: {
        skip 'only test data_directory if one is expected', 1 unless $expected_data_directory;
        is($model->data_directory,$expected_data_directory,'found expected data directory '. $expected_data_directory);
    }
    for my $param ($pp->params) {
        my $accessor = $param->name;
        my $value = $param->value;
        if ($accessor eq 'read_aligner_name' && $value =~ /^maq/) {
            $value = 'maq';
        }
        is($model->$accessor,$value,$accessor .' model indirect accessor');
    }

    SKIP: {
        skip 'no model to delete', 2 unless $model;
        # This would normally emit a warning message about deleting the create command object
        # but in the process of deleting the model it will also delete the command object,
        # leaving us no way to get the warning messages back.  Punt and just ignore them...
        delete_model($model);
    }
}


sub failed_create_model {
    my $reason = shift;
    my $params = shift;
    my %params = %{$params};
    my  $create_command = Genome::Model::Command::Define::ReferenceAlignment->create(%params);
    isa_ok($create_command,'Genome::Model::Command::Define');

    $create_command->dump_error_messages(0);
    $create_command->dump_warning_messages(0);
    $create_command->dump_status_messages(0);
    $create_command->dump_usage_messages(0);
    $create_command->queue_error_messages(1);
    $create_command->queue_warning_messages(1);
    $create_command->queue_status_messages(1);
    {
        *OLD = *STDOUT;
        my $variable;
        open OUT ,'>',\$variable;
        *STDOUT = *OUT;
        ok(!$create_command->execute, 'create command execution failed');
        *STDOUT = *OLD;
    };

    my @error_messages = $create_command->error_messages();
    my @warning_messages = $create_command->warning_messages();
    my @status_messages = $create_command->status_messages();
    ok(scalar(@error_messages), 'There are error messages');
    #like($error_messages[0], qr($reason), 'Error message about '. $reason);
    ok(!scalar(@warning_messages), 'no warning message');
    ok(!scalar(@status_messages), 'no status message');
}

sub delete_model {
    my $model = shift;
    ok($model->delete,'delete model');
}

1;

#$HeadURL$
#$Id$
