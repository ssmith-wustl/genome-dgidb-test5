package Genome::Model::Event;

use strict;
use warnings;
use File::Path;

our $log_base = '/gscmnt/sata114/info/medseq/model_data/logs/';

use Genome;
class Genome::Model::Event {
    is => ['Genome::Model::Command'],
    type_name => 'genome model event',
    table_name => 'GENOME_MODEL_EVENT',
    is_abstract => 1,
    first_sub_classification_method_name => '_resolve_subclass_name',
    sub_classification_method_name => '_resolve_subclass_name',
    id_by => [
        genome_model_event_id => { is => 'NUMBER', len => 11 },
    ],
    has => [
        model                           => { is => 'Genome::Model', id_by => 'model_id', constraint_name => 'GME_GM_FK' },

        event_type                      => { is => 'VARCHAR2', len => 255 },
        event_status                    => { is => 'VARCHAR2', len => 32 },
        user_name                       => { is => 'VARCHAR2', len => 64 },
    ],
    has_optional => [
                  read_set_id    => {
                                     is => 'NUMBER',
                                     len => 11,
                                     column_name => 'RUN_ID',
                                     doc => 'the id of thegenome_model_run on which to operate',
                                 },
                     ref_seq_id        => {
                                           is => 'NUMBER',
                                           len => 11,
                                           doc => "identifies the refseq"
                                       },
        parent_event                    => {
                                            is => 'Genome::Model::Event',
                                            id_by => ['parent_event_id'],
                                            constraint_name => 'GME_PAEID_FK'
                                        },
        prior_event                     => {
                                            is => 'Genome::Model::Event',
                                            id_by => ['prior_event_id'],
                                            constraint_name => 'GME_PPEID_FK'
                                        },
        date_completed                  => { is => 'TIMESTAMP', len => 20 },
        date_scheduled                  => { is => 'TIMESTAMP', len => 20 },

        lsf_job_id                      => { is => 'VARCHAR2', len => 64 },
        retry_count                     => { is => 'NUMBER', len => 3 },
        status_detail                   => { is => 'VARCHAR2', len => 200 },
        # bug requiring these explicitly when the reference is circular?
        parent_event_id                 => { is => 'NUMBER', len => 11 },
        prior_event_id                  => { is => 'NUMBER', len => 11 },
        should_calculate => {
                             doc => "a flag to determine metric calculations",
                             calculate_from => ['event_status'],
                             calculate => q|
                                 if ($event_status eq 'Failed' or $event_status eq 'Crashed') {
                                     return 0;
                                 }
                                 return 1;
                             |,
                         },
       build_directory => 
                          {
                           doc => "the directory where this step should put data",
                           calculate_from => ['parent_event'],
                           calculate => q| return $parent_event->data_directory |,
                           },   
    ],
    has_many_optional => [
        sibling_events                  => { via => 'parent_event', to => 'child_events' },
        child_events                    => {
                                            is => 'Genome::Model::Event',
                                            reverse_id_by => 'parent_event'
                                        },
        inputs                          => { is => 'Genome::Model::Event::Input',  reverse_id_by => 'event' },
        outputs                         => { is => 'Genome::Model::Event::Output', reverse_id_by => 'event' },
        metrics                         => { is => 'Genome::Model::Event::Metric', reverse_id_by => 'event' },
        metric_names                    => { via => 'metrics', to => 'name' },
    ],
    subclass_description_preprocessor   => '_preprocess_subclass_description',
    schema_name => 'GMSchema',
    data_source => 'Genome::DataSource::GMSchema',
};

sub _preprocess_subclass_description {
    my ($class,$desc) = @_;
    my $has = $desc->{has};
    for my $attribute (values %$has) {
        #print "event has $attribute " . Data::Dumper::Dumper($attribute) ,"\n";
        # via => 'inputs', to => 'value', where => [ name => 'foobar' ]
        if ($attribute->{is_input}) {
            delete($attribute->{is_input});
            $attribute->{via} = 'inputs';
            $attribute->{to} = 'value';
            $attribute->{where} = [ name => $attribute->{property_name} ];
        } elsif ($attribute->{is_output}) {
            delete($attribute->{is_output});
            $attribute->{via} = 'outputs';
            $attribute->{to} = 'value';
            $attribute->{where} = [ name => $attribute->{property_name} ];
        } elsif ($attribute->{is_param}) {
            die($attribute->{property_name} .' is a param and parameters are not handled correctly by events');
        }
        $has->{$attribute->{property_name}} = $attribute;
    }
    $desc->{has} = $has;
    return $desc;
}

sub create {
    my $class = shift;
    my $self = $class->SUPER::create(@_);
    return unless $self;
    unless ($self->event_type) {
        $self->event_type($self->command_name);
    }
    unless ($self->date_scheduled) {
        $self->date_scheduled(UR::Time->now);
    }
    unless ($self->user_name) {
        $self->user_name($ENV{USER});
    }
    return $self;
}

sub revert {
    my $self = shift;
    my @metrics = $self->metrics;
    my @outputs = $self->outputs;
    for my $output (@outputs) {
            if ($output->name eq 'Hostname') {
                $self->warning_message("Attempting to cleanup a blade /tmp/ file...");
                return unless $self->cleanup_the_mapmerge_I_specify($output);
            }
    }
    for my $obj (@metrics,@outputs) {
        $self->warning_message("deleting " . $self->class . " " . $self->id);
         #this delete is a general UR delete not the cute delete just below - Jim & Chris
        $obj->delete;
    }
    return 1;
}

sub delete {
    my $self = shift;
    $self->warning_message("deleting " . $self->class . " " . $self->id);
    $self->revert;
    my @inputs = $self->inputs;
    for my $obj (@inputs) { 
        $self->warning_message("deleting " . $obj->class . " " . $obj->id);
        $obj->delete;
    };
    $self->SUPER::delete();
    return 1;
}

sub base_temp_directory {
    my $self = shift;
    return $self->{base_temp_directory} if $self->{base_temp_directory};
    
    my $id = $self->id;
    
    my $event_type = $self->event_type;
    my ($base) = ($event_type =~ /([^\s]+) [^\s]+$/);
    
    my $time = UR::Time->now;
    $time =~ s/\s\: /_/g;
    
    my $dir = "/tmp/gm-$base-$time-$id-XXXX";
    $dir =~ s/ /-/g;
    $dir = File::Temp::tempdir($dir, CLEANUP => 1);
    $self->{base_temp_directory} = $dir;
    $self->create_directory($dir);
    
    return $dir;
}

my $anonymous_temp_file_count=0;
sub create_temp_file_path {
    my $self = shift;
    my $name = shift;
    unless ($name) {
        $name = 'anonymous' . $anonymous_temp_file_count++;
    }
    my $dir = $self->base_temp_directory;
    my $path = "$dir/$name";
    if (-e $path) {
        die "temp path $path already exists!";
    }
    return $path;
}

sub create_temp_file {
    my $self = shift;
    my $path = $self->create_temp_file_path(@_);    
    my $fh = IO::File->new(">$path");
    unless ($fh) {
        die "Failed to create temp file $path!";
    }
    return ($fh,$path) if wantarray;
    return $fh;
}

sub create_temp_directory {
    my $self = shift;
    my $path = $self->create_temp_file_path(@_);
    $self->create_directory($path);
    return $path;
}

sub shellcmd {
    # execute a shell command in a standard way instead of using system()\
    # verifies inputs and ouputs, and does detailed logging...
    
    # TODO: add IPC::Run's w/ timeout but w/o the io redirection...
    
    my ($self,%params) = @_;
    my $cmd                         = delete $params{cmd};
    my $output_files                = delete $params{output_files};
    my $input_files                 = delete $params{input_files};
    my $skip_if_output_is_present   = delete $params{skip_if_output_is_present} || 1;
    if (%params) {
        my @crap = %params;
        Carp::confess("Unknown params passed to shellcmd: @crap");
    }
    
    if ($output_files and @$output_files) {
        my @found_outputs = grep { -e $_ } @$output_files;
        if ($skip_if_output_is_present
            and @$output_files == @found_outputs
        ) {
            $self->status_message(
                "SKIP RUN (output is present):     $cmd\n\t"
                . join("\n\t",@found_outputs)
            );
            return 1;
        }
    }
    
    if ($input_files and @$input_files) {
        my @missing_inputs = grep { not -s $_ } @$input_files;
        if (@missing_inputs) {
            die "CANNOT RUN (missing inputs):     $cmd\n\t"
                . join("\n\t", map { -e $_ ? "(empty) $_" : $_ } @missing_inputs);
        }
    }
    
    $self->status_message("RUN: $cmd");
    my $exit_code = system($cmd);
    $exit_code /= 256;
    if ($exit_code) {
        die "ERROR RUNNING COMMAND.  Exit code $exit_code, msg $! from: $cmd";
    }
    
    if ($output_files and @$output_files) {
        my @missing_outputs = grep { not -s $_ } @$output_files;
        if (@missing_outputs) {
            for (@$output_files) { unlink $_ }
            die "MISSING OUTPUTS! @missing_outputs\n";
            #    . join("\n\t", map { -e $_ ? "(empty) $_" : $_ } @missing_outputs);
        }
    }
    
    return 1;
}

sub check_for_existence {
    my ($self,$path,$attempts) = @_;

    unless (defined $attempts) {
        $attempts = 5;
    }

    my $try = 0;
    my $found;
    while (!$found && $try < $attempts) {
        $found = -e $path;
        sleep(1);
        $try++;
        if ($found==1) {
            $self->status_message("existence check passed: $path");
            return $found;
        } 
    }
    return;
}

sub create_file {
    my ($self, $output_name, $path) = @_;
    $DB::single=1;
    if (!$path) {
        die "Output $output_name opened without a specified path!"
    }
    elsif (my @existing = $self->outputs(name => $output_name)) {
        if ($output_name and $existing[0]->value ne $path) {
            die "Input $output_name already exists with value " . $existing[0]->value
            . ".  Cannot open with value $path";
        }
        die "Attempting to re-create already created file! $output_name: $path";
    }
    elsif (-e $path) {
        die "File $path already exists!  Canot create output $output_name: $path\n";
    }
    else {
        my $fh = IO::File->new('>'.$path);
        die "Failed to make file $path! $?" unless $fh;    
        unless ($self->add_output(name => $output_name, value => $path)) {
            die "Error adding ouput $output_name $path!";
        }

    return $fh;
    }
}

sub open_file {
    my ($self, $input_name, $path) = @_;
    my @existing = $self->inputs(name => $input_name);
    if (@existing and $input_name and $existing[0]->value ne $input_name) {
        die "Input $input_name already exists with value " . $existing[0]->value
            . ".  Cannot open with value $path";
    }
    if (not @existing) {
        if (!$path) {
            die "Input $input_name opened without a specified path, and no path has been set yet!"
        }
        else {
            $self->add_input(name => $input_name, value => $path);
        }
    }
    my $fh = IO::File->new($path);
    die "Failed to open file $path! $?" unless $fh;
    if ( (!-p $path) and (-z $path) ) {
        warn "warning: opening zero-length file $path for input $input_name";
    }
    return $fh;
}

sub create_directory {
    my ($self, $path) = @_;
    my @parts = grep { length($_) } split('/',$path);
    my $dir = "/";
    for (@parts) {
        $dir .= $_ . '/';
        unless (-d $dir) {
            $self->status_message("creating directory $dir");
            mkdir $dir;
            unless(-d $dir) {
                die "Failed to create directory $dir: $!";
            }
            # TODO: fixme w/ Perl
            `chmod g+ws $dir`;
        }
    }
    unless (-d $path) {
        die "Failed to create directory $path: $?";
    }
    return $path;
}

sub _shell_args_property_meta {
    # exclude this class' commands from shell arguments
    return grep { 
            (
                $_->class_name eq __PACKAGE__
                    ? ($_->property_name eq 'model_id' ? 1 : 0)
                    : 1
            )
        } shift->SUPER::_shell_args_property_meta(@_);
}

# This is called by the infrastructure to appropriately classify abstract events
# according to their event type because of the "sub_classification_method_name" setting
# in the class definiton...
# TODO: replace with cleaner calculated property.
sub _resolve_subclass_name {
    my $class = shift;
    
    if (ref($_[0]) and $_[0]->isa(__PACKAGE__)) {
        my $event_type = $_[0]->event_type;
        return $class->_resolve_subclass_name_for_event_type($event_type);
    }
    elsif (my $event_type = $class->get_rule_for_params(@_)->specified_value_for_property_name('event_type')) {
        return $class->_resolve_subclass_name_for_event_type($event_type);
    }
    else {
        # this uses the model
        return $class->_get_sub_command_class_name(@_);
    }
}

# This is called by some legacy code.
sub class_for_event_type {
    my $self = shift;
    return $self->_resolve_subclass_name_for_event_type($self->event_type);
}

# This is called by both of the above.
sub _resolve_subclass_name_for_event_type {
    my ($class,$event_type) = @_;
    my @command_parts = split(' ',$event_type);
    my $genome_model = shift @command_parts;
    if ($genome_model !~ m/genome-model/) {
        $class->error_message("Malformed event-type $event_type.  Expected it to begin with 'genome-model'");
        return;
    }

    foreach ( @command_parts ) {
        my @sub_parts = map { ucfirst } split('-');
        $_ = join('',@sub_parts);
    }

    my $class_name = join('::', 'Genome::Model::Command' , @command_parts);

    # TEMP
    $class_name =~ s/AddReads::/Build::ReferenceAlignment::/;
    return $class_name;
}

sub desc {
    my $self = shift;
    return $self->id . " (" . $self->event_type . ")";
}

# Override the default message handling to auto-instantiate a log handle.
# TODO: have the command tell the current context to take messages

our @process_logs;

sub _get_msgdata {
    my $self = $_[0];
    my $msgdata = $self->SUPER::_get_msgdata;
    return $msgdata if $msgdata->{gm_fh_set};
    $msgdata->{gm_fh_set} = 1;

    my $name = $log_base;
    use Sys::Hostname;
    if (ref($self)) {
        no warnings;
        $name .= "/" . join('.', UR::Time->now, hostname(), $$, $self->id, $self->event_type, 
            $self->model_id,
            ($self->lsf_job_id || 'NOJOB')
        ) . ".log";
    }
    else {
        $name .= "/" . join(".", UR::Time->now, hostname(), $$) . ".process-log";
    }
    $name =~ s/\s/_/g;

    my $logfh = $msgdata->{gm_logfh} = IO::File->new(">$name");
    $logfh->autoflush(1);
    chmod(0644, $name) or die "chmod $name failed: $!";
    require IO::Tee;
    my $fh = IO::Tee->new(\*STDERR, $logfh) or die "failed to open tee for $name: $!";        

    push @process_logs, [$name,$logfh,$fh];

    $self->dump_status_messages($fh);
    $self->dump_warning_messages($fh);
    $self->dump_error_messages($fh);
 
    return $msgdata;
}

END {
    for (@process_logs) {
        my ($name,$logfh,$fh) = @$_;
        eval { $fh->close; };
        eval { $logfh->close; };
        if (-z $name) {
            print STDERR "removing empty file $name\n";
            unlink $name;
        }
    }
}

sub map_files_for_refseq {
    my $self = shift;
    my $ref_seq_id=shift;
    my $model= $self->model;
    
    my $path = $self->alignment_submaps_dir_for_lane;
    my @map_files =  (sprintf("%s/%s_unique.map",$path, $ref_seq_id));
    if($model->is_eliminate_all_duplicates) {
        return @map_files;
    }
    else {
        push (@map_files, sprintf("%s/%s_duplicate.map",$path, $ref_seq_id));
        return @map_files;
    }
}

sub bsub_rusage {
    # TODO: add the xeon spec
    #return "-R 'select[type=LINUX64]'";model=='Intel_Xeon360'
    return "-R 'select[model==Intel_Xeon360]'";
}

sub execute_with_bsub {
    my ($self, %params) = @_;
    my $last_event = $params{last_event};
    my $dep_type = $params{dep_type};
    my $queue = $params{bsub_queue};
    my $bsub_args = $params{bsub_args};
    my $dependency_expression = $params{dependency_expression};
    my $model_id = $self->model_id;

## should check if $self isa Command??
    $queue ||= 'long';
    $dep_type ||= 'ended';
    

    $DB::single = $DB::stopper;

    unless($dependency_expression) {
        $dependency_expression = $last_event->lsf_job_id if defined $last_event;
    }

    if (my $bsub_rusage = $self->bsub_rusage) {
        $bsub_args .= ' ' . $bsub_rusage;
    }

    my $class = $self->class;
    my $id = $self->id;

    my $cmd = "genome-model bsub-helper";

    my $event_id = $self->genome_model_event_id;
    my $prior_event_id = $last_event->genome_model_event_id if defined $last_event;

    my $log_dir = $self->resolve_log_directory;
    unless (-d $log_dir) {
        eval { mkpath($log_dir) };
        if ($@) {
            $self->error_message("Couldn't create run directory path $log_dir: $@");
            return;
        }
    }
  
    my $err_log_file = sprintf("%s/%s.err", $self->resolve_log_directory, $event_id);
    my $out_log_file = sprintf("%s/%s.out", $self->resolve_log_directory, $event_id);
    $bsub_args .= ' -o ' . $out_log_file . ' -e ' . $err_log_file;

    my $cmdline;
    { no warnings 'uninitialized';
        $cmdline = "bsub -q $queue $bsub_args" .
                   ($dependency_expression && " -w '$dep_type($dependency_expression)'") .
                   " $cmd --model-id $model_id --event-id $event_id " .
                   ($prior_event_id && " --prior-event-id $prior_event_id");
    }
    
    $self->status_message("Running command: " . $cmdline);

    # Header for output and error files
    for my $log_file ( $err_log_file, $out_log_file )
    {
        $DB::single = $DB::stopper;
        if(-e $log_file && (stat($log_file))[2] != 0100664) { 
            unless ( chmod(0664, $log_file) )
            {
                $self->error_message("Can't chmod log file ($log_file)");
                return;
            }
        }
        my $fh = IO::File->new(">> $log_file");
        $fh->print("\n\n########################################################\n");
        $fh->print( sprintf('Submitted at %s: %s', UR::Time->now, $cmdline) );
        $fh->close;
    }

    my $bsub_output = `$cmdline`;
    my $retval = $? >> 8;

    if ($retval) {
        $self->error_message("bsub returned a non-zero exit code ($retval), bailing out");
        return;
    }
    my $bsub_job_id;
    if ($bsub_output =~ m/Job <(\d+)>/) {
        $bsub_job_id = $1;

    } else {
        $self->error_message('Unable to parse bsub output, bailing out');
        $self->error_message("The output was: $bsub_output");
        return;
    }

    return $bsub_job_id;
}

# Scheduling

sub schedule {
    my $self = shift;

    $self->event_status("Scheduled");
    $self->date_scheduled( UR::Time->now );
    $self->date_completed(undef);

    return 1;
}

sub is_reschedulable {
    my($self) = @_;

    return 1; # was part of bsub helper, may change implementation again

    if ($self->event_status eq 'Failed' and
       $self->retry_count < $self->max_retries) {

        return 1;
    } else {
        return 0;
    }
}

sub max_retries {
    2;  
}

sub get_prior_event {
    my $self = shift;

    if (defined $self->prior_event_id) {
        return Genome::Model::Event->get($self->prior_event_id);
    }

    return;
}

sub verify_prior_event {
    my $self = shift;

    if (defined $self->prior_event_id) {
        my $prior_event = $self->get_prior_event;
        unless ($prior_event->event_status eq 'Succeeded') {
            $self->error_message('Prior event '. $self->prior_event_id .' is not Succeeded');
            return;
        }
    }

    return 1;
}


#this method is just a wrapper that tries a database call, then tries to calculate the metric and store it if its not already in the db
sub get_metric_value {
    my $self = shift;
    my $metric_name = shift;

    return unless($metric_name);

    my $metric=$self->get_metric($metric_name);
    unless ($metric) {
         return "Not Found";
    }
    return $metric->value;
}

#this method is like gimme that metric from the database or fail if it doesn't exist. 
#Its public for those that want to generate a view without impyling an hour computation for unknown values
sub get_metric {
    my $self = shift;
    my @metric_names = @_;

    unless (@metric_names) {
        @metric_names = $self->metrics_for_class;
    }

    if (@metric_names == 1) {
        # A hack to make a cgi script faster.  It preloads all the metrics, but the UR
        # cache system isn't able to find them because of the in-clause.  
        return Genome::Model::Event::Metric->get(name => $metric_names[0], event_id => $self->id);
    } else {
        return Genome::Model::Event::Metric->get(
                                             name => \@metric_names,
                                             event_id => $self->id,
                                         );
    }
}

sub has_all_metrics {
    my $self = shift;

    my @metric_names = $self->metrics_for_class;
    for my $metric_name (@metric_names) {
        unless ($self->get_metric($metric_name)) {
            $self->error_message("Metric $metric_name does not exist for event_id ". $self->id);
            return 0;
        }
    }
    return 1;
}


#this method is like can i have that metric? no? then i'll make one!
sub resolve_metric {
    my $self = shift;
    my @metric_names = @_;

    unless (@metric_names) {
        @metric_names = $self->metrics_for_class;
    }

    my @metrics;
    for my $metric_name (@metric_names) {
        my $metric = $self->get_metric($metric_name);

        unless ($metric) {
            $metric = $self->generate_metric($metric_name);
            unless ($metric) {
                $self->error_message("Unable to generate requested metric $metric_name for event_id ". $self->id);
                next;
            }
        }
        push @metrics, $metric;
    }
    return @metrics;
}


#this method is called by resolve metric and it dynamically figures out the calculate method to call to store a new metric
sub generate_metric {
    my $self = shift;
    my @metric_names = @_;

    unless (@metric_names) {
        @metric_names = $self->metrics_for_class;
    }

    my @metrics;
    for my $metric_name (@metric_names) {
        my $metric = $self->get_metric($metric_name);

        my $calculate_method = '_calculate_'. $metric_name;
        unless ($self->can($calculate_method)) {
            $self->error_message("Event ". $self->id ." can not $calculate_method");
            next;
        }

        my $value = $self->$calculate_method;
        unless(defined $value) {
            $self->error_message("Value not defined for metric $metric_name using method $calculate_method");
            next;
        }
        if ($metric) {
            $metric->value($value);
        } else {
            $metric = $self->add_metric(
                                        name    => $metric_name,
                                        value   => $value,
                                    );
        }
        unless ($metric) {
            $self->error_message("Could not create/update metric $metric_name with value $value");
            return;
        }
        push @metrics, $metric;
    }
    if($self->can('cleanup_transient_properties')) {
        $self->cleanup_transient_properties();
    }
    return @metrics;
}


sub metrics_for_class {
    my $self = shift;
    $self->error_message("Please implement me! I do not have metrics_for_class");
    return 0;
}

1;
