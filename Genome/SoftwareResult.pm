package Genome::SoftwareResult;

use strict;
use warnings;

use Genome;
use Data::Dumper;
use Digest::MD5 qw(md5_hex);

class Genome::SoftwareResult {
    is_abstract => 1,
    table_name => 'SOFTWARE_RESULT',
    subclass_description_preprocessor => 'Genome::SoftwareResult::_expand_param_and_input_properties',
    subclassify_by => 'result_class_name',
    id_by => [
        id => { is => 'NUMBER', len => 20 },
    ],
    attributes_have => [
        is_param => { is => 'Boolean', is_optional=>'1' },
        is_input => { is => 'Boolean', is_optional=>'1' },
        is_metric => { is => 'Boolean', is_optional=>'1' }
    ],
    has => [
        software            => { is => 'Genome::Software', is_transient => 1, default_value=>'Genome::Software'},
        software_class_name => { via => 'software', to => 'class' },
        software_version    => { is => 'VARCHAR2', len => 64, column_name => 'VERSION', is_optional => 1 },
        result_class_name   => { is => 'VARCHAR2', len => 255, column_name => 'CLASS_NAME' },
        inputs_bx           => { is => 'UR::BoolExpr', id_by => 'inputs_id', is_optional => 1 },
        inputs_id           => { is => 'VARCHAR2', len => 4000, column_name => 'INPUTS_ID', implied_by => 'inputs_bx', is_optional => 1 },
        params_bx           => { is => 'UR::BoolExpr', id_by => 'params_id', is_optional => 1 },
        params_id           => { is => 'VARCHAR2', len => 4000, column_name => 'PARAMS_ID', implied_by => 'params_bx', is_optional => 1 },
        output_dir          => { is => 'VARCHAR2', len => 1000, column_name => 'OUTPUTS_PATH', is_optional => 1 },
    ],
    has_many_optional => [
        params              => {is => 'Genome::SoftwareResult::Param', reverse_as => 'software_result'},
        inputs              => {is => 'Genome::SoftwareResult::Input', reverse_as => 'software_result'},
        metrics             => {is => 'Genome::SoftwareResult::Metric', reverse_as => 'software_result'},
    ],
    schema_name => 'GMSchema',
    data_source => 'Genome::DataSource::GMSchema',
    doc => 'base class for managed data sets, with database tracking for params, inputs, metrics, and disk',
};

our %LOCKS;

sub get_or_create {
    my $class = shift;

    my $params_processed = $class->_gather_params_for_get_or_create(@_);
    my %is_input = %{$params_processed->{inputs}};
    my %is_param = %{$params_processed->{params}};
    
    my @objects = $class->get(%is_input, %is_param);
    # print Data::Dumper::Dumper(\@objects);

    unless (@objects) {
        @objects = $class->create(@_);
        unless (@objects) {
            # see if the reason we failed was b/c the objects were created while we were locking...
            @objects = $class->get(%is_input, %is_param);
            unless (@objects) {
                $class->error_message("Could not create a $class for params " . Data::Dumper::Dumper(\@_) . " even after trying!");
                die $class->error_message();
            }
        }
    }
   
    if (@objects > 1) {
        return @objects if wantarray;
        die "Multiple matches for alignment but get or create was called in scalar context";
    } else {
        return $objects[0];
    }
}

sub create {
    my $class = shift;

     if ($class eq __PACKAGE__ || $class->__meta__->is_abstract) {
        # this class is abstract, and the super-class re-calls the constructor from the correct subclass
        return $class->SUPER::create(@_);
    }

    my $params_processed = $class->_gather_params_for_get_or_create(@_);
    my %is_input = %{$params_processed->{inputs}};
    my %is_param = %{$params_processed->{params}};

    my @previously_existing = $class->get(%is_input, %is_param);
    if (@previously_existing > 0) {
        $class->error_message("Attempt to create an $class but it looks like we already have one with those params " . Dumper(\@_));
        return;
    }

    my $lock;
    unless ($lock = $class->lock(%is_input, %is_param)) {
        die "Failed to get a lock for " . Dumper(\%is_input,\%is_param);
    }
    
    my $unlock_callback = sub {
        Genome::Utility::FileSystem->unlock_resource(resource_lock=>$lock) || die "Failed to unlock after committing software result";
        print "Cleaning up";
    };
    # TODO; if an exception occurs before this is assigned to the object, we'll have a stray lock
    # We need to ensure that we get cleanup on die.

    # we might have had to wait on the lock, in which case someone else was probably creating that alignment.
    # do a "reload" here to force another trip back to the database to see if a software result was created
    # while we were waiting on the lock.
    (@previously_existing) = UR::Context->current->reload($class,%is_input,%is_param);

    if (@previously_existing > 0) {
        $class->error_message("Attempt to create an $class but it looks like we already have one with those params " . Dumper(\@_));
        return; 
    }

    my $self = $class->SUPER::create(@_);
    unless ($self) {
        $unlock_callback->();
        return;
    }

    $self->create_subscription(method=>'commit', callback=>$unlock_callback);
    $self->create_subscription(method=>'delete', callback=>$unlock_callback);
    
    if (my $output_dir = $self->output_dir) {
        if (-d $output_dir) {
            my @files = glob("$output_dir/*");
            if (@files) {
                $self->delete;
                die "Found files in output directory $output_dir!:\n\t" 
                    . join("\n\t", @files);
            }
            else {
                $self->status_message("No files in $output_dir.");
            }
        }
        else {
            $self->status_message("Creating output directory $output_dir...");
            eval {
                Genome::Utility::FileSystem->create_directory($output_dir)
            };
            if ($@) {
                $self->delete;
                die $@;
            }
        }
    }

    my $software = $self->software;
    $self->inputs_bx($software->inputs_bx) unless defined $self->inputs_bx;
    $self->software_version($software->resolve_software_version) unless defined $self->software_version;
    $self->result_class_name($class);
    return $self;
}

sub _expand_param_and_input_properties {
    my ($class, $desc) = @_;

    $DB::single = 1;
    for my $t ('input','param','metric') {
        while (my ($prop_name, $prop_desc) = each(%{ $desc->{has} })) {
            if (exists $prop_desc->{'is_'.$t} and $prop_desc->{'is_'.$t}) {
                $prop_desc->{'to'} = $t.'_value';
                $prop_desc->{'is_delegated'} = 1;
                $prop_desc->{'where'} = [
                    $t.'_name' => $prop_name
                ];
                $prop_desc->{'via'} = $t.'s';
            }
        }
    }

    return $desc;
}

sub delete {
    my $self = shift;

    my @to_nuke = ($self->params, $self->inputs, $self->metrics); 

    for (@to_nuke) {
        unless($_->delete) {
            die "Failed to delete: " . Data::Dumper::Dumper($_);
        }
    }

    return $self->SUPER::delete(@_); 
}


sub lock {
    my $self = shift;
    
    my $resource_lock_name = $self->_resolve_lock_name(@_);

    # if we're already locked, just increment the lock count
    $LOCKS{$resource_lock_name} += 1;
    return $resource_lock_name if ($LOCKS{$resource_lock_name} > 1);
   
    my $lock = Genome::Utility::FileSystem->lock_resource(resource_lock => $resource_lock_name, max_try => 2);
    unless ($lock) {
        $self->status_message("This data set is still being processed by its creator.  Waiting for existing data lock...");
        $lock = Genome::Utility::FileSystem->lock_resource(resource_lock => $resource_lock_name);
        unless ($lock) {
            $self->error_message("Failed to get existing data lock!");
            die($self->error_message);
        }
    }

    return $lock;
}

sub unlock {
    my $self = shift;

    my $resource_lock_name = $self->_resolve_lock_name(@_);

    if (!exists $LOCKS{$resource_lock_name})  {
        $self->error_message("Attempt to unlock $resource_lock_name but this was never locked!");
        die $self->error_message;
    }
    $LOCKS{$resource_lock_name} -= 1;
    
    return if ($LOCKS{$resource_lock_name} > 1);
    
    unless (Genome::Utility::FileSystem->unlock_resource(resource_lock=>$resource_lock_name)) {
        $self->error_message("Couldn't unlock $resource_lock_name.  error message was " . $self->error_message);
        die $self->error_message;
    }

    delete $LOCKS{$resource_lock_name};
    return 1;
}

sub _resolve_lock_name {
    my $self = shift;

    if (ref($self)) {
        my $class =ref($self);
        my %is_input;
        my %is_param;
        my $class_object = $class->get_class_object;
        for my $key ($class->property_names) {
            my $meta = $class_object->property_meta_for_name($key);
            if ($meta->{is_input} && $self->$key) {
                $is_input{$key} = $self->$key;
            } elsif ($meta->{is_param} && defined $self->$key) {
                $is_param{$key} = $self->$key; 
            }
        }

        return $class->_resolve_lock_name(%is_input, %is_param);
    }
    my $be = UR::BoolExpr->resolve_normalized($self, @_);
    my $params_list=join "___", $be->params_list;
    # sub out dangerous directory separators
    $params_list =~ s/\//\./g;
    my $params_list_hash = md5_hex($params_list);
    
    my $resource_lock_name = "/gsc/var/lock/alignments/" .  $params_list_hash;
}

1;

#$Rev$:
#$HeadURL$:
#$Id$:
    
