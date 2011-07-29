package Genome::SoftwareResult;

use strict;
use warnings;

use Genome;
use Digest::MD5 qw(md5_hex);
use Data::Dumper;

class Genome::SoftwareResult {
    is_abstract => 1,
    table_name => 'SOFTWARE_RESULT',
    subclass_description_preprocessor => 'Genome::SoftwareResult::_expand_param_and_input_properties',
    subclassify_by => 'subclass_name',
    id_by => [
        id => { is => 'NUMBER', len => 20 },
    ],
    attributes_have => [
        is_param => { is => 'Boolean', is_optional=>'1' },
        is_input => { is => 'Boolean', is_optional=>'1' },
        is_metric => { is => 'Boolean', is_optional=>'1' }
    ],
    has => [
        module_version      => { is => 'VARCHAR2', len => 64, column_name => 'VERSION', is_optional => 1 },
        subclass_name       => { is => 'VARCHAR2', len => 255, column_name => 'CLASS_NAME' },
        inputs_bx           => { is => 'UR::BoolExpr', id_by => 'inputs_id', is_optional => 1 },
        inputs_id           => { is => 'VARCHAR2', len => 4000, column_name => 'INPUTS_ID', implied_by => 'inputs_bx', is_optional => 1 },
        params_bx           => { is => 'UR::BoolExpr', id_by => 'params_id', is_optional => 1 },
        params_id           => { is => 'VARCHAR2', len => 4000, column_name => 'PARAMS_ID', implied_by => 'params_bx', is_optional => 1 },
        output_dir          => { is => 'VARCHAR2', len => 1000, column_name => 'OUTPUTS_PATH', is_optional => 1 },
        test_name           => { is_param => 1, is_delegated => 1, is_mutable => 1, via => 'params', to => 'param_value', where => ['param_name' => 'test_name'], is => 'Text', doc => 'Assigns a testing tag to the result.  These will not be used in default processing', is_optional => 1 },
    ],
    has_many_optional => [
        params              => { is => 'Genome::SoftwareResult::Param', reverse_as => 'software_result'},
        inputs              => { is => 'Genome::SoftwareResult::Input', reverse_as => 'software_result'},
        metrics             => { is => 'Genome::SoftwareResult::Metric', reverse_as => 'software_result'},
        users               => { is => 'Genome::SoftwareResult::User', reverse_as => 'software_result'},
        build_ids           => { via => 'users', to => 'user_id', } # where => ['user_class_name isa' => 'Genome::Model::Build'] },
    ],
    schema_name => 'GMSchema',
    data_source => 'Genome::DataSource::GMSchema',
    doc => 'base class for managed data sets, with database tracking for params, inputs, metrics, and disk',
};

our %LOCKS;

#This requires the full set of params (as would be passed to create) in order to work correctly
sub get_with_lock {
    my $class = shift;

    my $params_processed = $class->_gather_params_for_get_or_create($class->_preprocess_params_for_get_or_create(@_));

    my %is_input = %{$params_processed->{inputs}};
    my %is_param = %{$params_processed->{params}};

    my $lock;
    my $subclass = $params_processed->{subclass};
    unless ($lock = $subclass->lock(%is_input, %is_param)) {
        die "Failed to get a lock for " . Dumper(\%is_input,\%is_param);
    }

    my @objects;
    eval {
        @objects = $class->get(%is_input, %is_param);
    };
    my $error = $@;

    $class->status_message("Cleaning up lock $lock...");
    $subclass->unlock(%is_input, %is_param) || die "Failed to unlock after getting software result";
    $class->status_message("Cleanup completed for lock $lock.");

    if($error) {
        $class->error_message('Failed in get! ' . $error);
        die $class->error_message;
    }

    if (@objects > 1) {
        return @objects if wantarray;
        my @ids = map { $_->id } @objects;
        die "Multiple matches for $class but get or create was called in scalar context!  Found ids: @ids";
    } else {
        return $objects[0];
    }
}

sub get_or_create {
    my $class = shift;

    my $params_processed = $class->_gather_params_for_get_or_create($class->_preprocess_params_for_get_or_create(@_));
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
        my @ids = map { $_->id } @objects;
        die "Multiple matches for $class but get or create was called in scalar context!  Found ids: @ids";
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

    my $params_processed = $class->_gather_params_for_get_or_create($class->_preprocess_params_for_get_or_create(@_));
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
        $class->status_message("Cleaning up lock $lock...");
        Genome::Sys->unlock_resource(resource_lock=>$lock) || die "Failed to unlock after committing software result";
        $class->status_message("Cleanup completed for lock $lock.");
    };
    # TODO; if an exception occurs before this is assigned to the object, we'll have a stray lock
    # We need to ensure that we get cleanup on die.

    # we might have had to wait on the lock, in which case someone else was probably creating that entity
    # do a "reload" here to force another trip back to the database to see if a software result was created
    # while we were waiting on the lock.
    (@previously_existing) = UR::Context->current->reload($class,%is_input,%is_param);

    if (@previously_existing > 0) {
        $class->error_message("Attempt to create an $class but it looks like we already have one with those params " . Dumper(\@_));
        return; 
    }
    
    # We need to update the indirect mutable accessor logic for non-nullable
    # hang-offs to delete the entry instead of setting it to null.  Otherwise
    # we get SOFTWARE_RESULT_PARAM entries with a NULL, and unsavable PARAM_VALUE.
    # also remove empty strings because that's equivalent to a NULL to the database

    # Do the same for inputs (e.g. alignment results have nullable segment values for instrument data, which are treated as inputs)
    my @param_remove = grep { not (defined $is_param{$_}) || $is_param{$_} eq "" } keys %is_param;
    my @input_remove = grep { not (defined $is_input{$_}) || $is_input{$_} eq "" } keys %is_input;
    my $bx = $class->define_boolexpr($class->_preprocess_params_for_get_or_create(@_));
    for my $i (@param_remove, @input_remove) {
        $bx = $bx->remove_filter($i);
    }

    my $self = $class->SUPER::create($bx);
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
                Genome::Sys->create_directory($output_dir)
            };
            if ($@) {
                $self->delete;
                die $@;
            }
        }
    }

    $self->module_version($self->resolve_module_version) unless defined $self->module_version;
    $self->subclass_name($class);
    return $self;
}

sub _preprocess_params_for_get_or_create {
    my $class = shift;
    if(scalar @_ eq 1) {
        return @_; #don't process a UR::BoolExpr or plain ID
    }

    my %params = @_;

    my $class_object = $class->__meta__;
    for my $key ($class->property_names) {
        my $meta = $class_object->property_meta_for_name($key);

        for my $t ('input', 'param') {
            if ($meta->{'is_' . $t} && $meta->is_many) {
                my $value_list = delete $params{$key};
                if(defined $value_list) {
                    my @values = sort @$value_list;
                    my $t_params = $params{$t . 's'} || [];
                    for my $i (0..$#values) {
                        push @$t_params, {$t . '_name' => $key . '-' . $i, $t . '_value' => $values[$i]};
                    }
                    $params{$t . 's'} = $t_params;

                    $params{$key . '_count'} = scalar @values;
                    $params{$key . '_md5'} = md5_hex( join(':', @values));
                } else {
                    $params{$key . '_count'} = 0;
                    $params{$key . '_md5'} = undef;
                }
            }
        }
    }
    return %params;
}

sub resolve_module_version {
    #TODO, this tries to get svn revision info, then snapshot info, then date commited to trunk.  This actually isn't used anywhere to verify versions, so as long as it doesn't die here we are ok for the time being
    my $self = shift;
    my $base_dir = $self->base_dir;
    my $path = $base_dir .'.pm';
    unless (-f $path) {
        die('Failed to find expected perl module '. $path);
    }

    if ($path =~ /\/gsc\/scripts\/opt\/genome-(\d+)\//) {
        return $1;
    }
    if ($path =~ /\/gsc\/scripts\/lib\/perl\//) {
        my $date = (stat($path))[9]; #mtime
        return 'app-'. $date;
    }
    #TODO: make condition for directory in svn tree that has not been added to svn

    #TODO: make condition for uncommited changes in svn tree, currently return zero
    #die('Failed to resolve_software_version for perl module path '. $path);
    return 0;
}

sub svn_info {
    my $self = shift;
    my $path = shift;
}

sub _expand_param_and_input_properties {
    my ($class, $desc) = @_;
    for my $t ('input','param','metric') {
        while (my ($prop_name, $prop_desc) = each(%{ $desc->{has} })) {
            if (exists $prop_desc->{'is_'.$t} and $prop_desc->{'is_'.$t}) {
                my $is_many = ($t ne 'metric' and exists $prop_desc->{'is_many'} and $prop_desc->{'is_many'});
                $prop_desc->{'to'} = $t.'_value';
                $prop_desc->{'is_delegated'} = 1;

                if($is_many) {
                    $prop_desc->{'where'} = [
                        $t.'_name like' => $prop_name . '-%',
                    ];
                } else {
                    $prop_desc->{'where'} = [
                        $t.'_name' => $prop_name
                    ];
                }

                $prop_desc->{'is_mutable'} = 1;
                $prop_desc->{'via'} = $t.'s';

                if($is_many) {
                    my $md5_name = $prop_name . '_md5';
                    unless(exists $desc->{has}{$md5_name}) {
                        my $md5_prop = {};
                        $md5_prop->{'is'} = 'Text';
                        $md5_prop->{'is_param'} = 1;
                        $md5_prop->{'is_delegated'} = 1;
                        $md5_prop->{'via'} = 'params';
                        $md5_prop->{'to'} = 'param_value';
                        $md5_prop->{'where'} = [
                            'param_name' => $md5_name
                        ];
                        $md5_prop->{'doc'} = 'MD5 sum of the sorted list of values for ' . $prop_name;
                        $md5_prop->{'is_mutable'} = 1;
                        $md5_prop->{'is_optional'} = 1;

                        $md5_prop->{'property_name'} = $md5_name;
                        $md5_prop->{'type_name'} = $desc->{type_name};
                        $md5_prop->{'class_name'} = $desc->{class_name};
                        $desc->{has}{$md5_name} = $md5_prop;
                    }

                    my $count_name = $prop_name . '_count';
                    unless(exists $desc->{has}{$count_name}) {
                        my $count_prop = {};
                        $count_prop->{'is'} = 'Number';
                        $count_prop->{'is_param'} = 1;
                        $count_prop->{'is_delegated'} = 1;
                        $count_prop->{'via'} = 'params';
                        $count_prop->{'to'} = 'param_value';
                        $count_prop->{'where'} = [
                            'param_name' => $count_name
                        ];
                        $count_prop->{'doc'} = 'number of values for ' . $prop_name;
                        $count_prop->{'is_mutable'} = 1;
                        $count_prop->{'is_optional'} = 1;

                        $count_prop->{'property_name'} = $count_name;
                        $count_prop->{'type_name'} = $desc->{type_name};
                        $count_prop->{'class_name'} = $desc->{class_name};
                        $desc->{has}{$count_name} = $count_prop;
                    }
                }
            }
        }
    }
    return $desc;
}

sub delete {
    my $self = shift;

    my $class_name = $self->class;
    my @users = $self->users;
    if (@users) {
        my $name = $self->__display_name__;
        die "Refusing to delete $class_name $name as it still has users:\n\t"
            .join("\n\t", map { $_->user_class . "\t" . $_->user_id } @users);
    }

    my @to_nuke = ($self->params, $self->inputs, $self->metrics); 

    #If we use any other results, unregister ourselves as users
    push @to_nuke, Genome::SoftwareResult::User->get(user_class_name => $class_name, user_id => $self->id);

    for (@to_nuke) {
        unless($_->delete) {
            die "Failed to delete: " . Data::Dumper::Dumper($_);
        }
    }

    #creating an anonymous sub to delete allocations when commit happens
    my $id = $self->id;
    my $upon_delete_callback = sub { 
        print "Now Deleting Allocation with owner_id = $id\n";
        my $allocation = Genome::Disk::Allocation->get(owner_id=>$id, owner_class_name=>$class_name);
        if ($allocation) {
            $allocation->deallocate; 
        }
    };

    #hook our anonymous sub into the commit callback
    $class_name->ghost_class->add_observer(aspect=>'commit', callback=>$upon_delete_callback);
    
    return $self->SUPER::delete(@_); 
}

sub lock {
    my $self = shift;
    
    my $resource_lock_name = $self->_resolve_lock_name(@_);

    # if we're already locked, just increment the lock count
    $LOCKS{$resource_lock_name} += 1;
    return $resource_lock_name if ($LOCKS{$resource_lock_name} > 1);
   
    my $lock = Genome::Sys->lock_resource(resource_lock => $resource_lock_name, max_try => 2);
    unless ($lock) {
        $self->status_message("This data set is still being processed by its creator.  Waiting for existing data lock...");
        $lock = Genome::Sys->lock_resource(resource_lock => $resource_lock_name);
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
    
    unless (Genome::Sys->unlock_resource(resource_lock=>$resource_lock_name)) {
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
    
    my $class_string = ref($self) || $self;
    $class_string =~ s/\:/\-/g;

    my $be = UR::BoolExpr->resolve_normalized($self, @_);
    no warnings;
    my $params_and_inputs_list=join "___", $be->params_list;
    # sub out dangerous directory separators
    $params_and_inputs_list =~ s/\//\./g;
    use warnings;
    my $params_and_inputs_list_hash = md5_hex($params_and_inputs_list);
   

    my $resource_lock_name = "/gsc/var/lock/genome/$class_string/" .  $params_and_inputs_list_hash;
}
# override _resolve_lock_name (for testing) to append username and time
if ($ENV{UR_DBI_NO_COMMIT}) {
    warn 'Overriding Genome::SoftwareResult::_resolve_lock_name since UR_DBI_NO_COMMIT is on.' . "\n";
    my $suffix = Genome::Sys->username . '_' . time;
    my $original_resolve_lock_name_sub = \&Genome::SoftwareResult::_resolve_lock_name;
    *Genome::SoftwareResult::_resolve_lock_name = sub {
        my $lock_name = &$original_resolve_lock_name_sub(@_);
        $lock_name .= "_$suffix" unless $lock_name =~ /$suffix/;
        return $lock_name;
    };
}

sub metric_names {
    my $class = shift;
    my $meta = $class->__meta__;
    my @properties = grep { $_->{is_metric} } $meta->_legacy_properties();
    my @names = map { $_->property_name } @properties;
    return @names;
}

sub metrics_hash {
    my $self = shift;
    my @names = $self->metric_names;
    my %hash = map { $self->name } @names;
    return %hash;
}

sub generate_expected_metrics {
    my $self = shift;
    my @names = @_;
    unless (@names) {
        @names = $self->metric_names;
    }
    
    # pre-load all metrics
    my @existing_metrics = $self->metrics;
    
    for my $name (@names) {
        my $metric = $self->metric(name => $name);
        if ($metric) {
            $self->status_message(
                $self->display_name . " has metric "
                . $metric->name 
                . " with value "
                . $metric->value
            );
            next;
        }
        my $method = "_calculate_$name";
        unless ($self->can($method)) {
            $self->error_message("No method $method found!");
            die $self->error_message;
        }
        $self->status_message(
            $self->display_name . " is generating a value for metric "
            . $metric->name 
            . "..."
        );
        my $value = $self->$method();
        unless (defined($value)) {
            $self->error_message(
                $self->display_name . " has metric "
                . $metric->name 
                . " FAILED TO CALCULATE A DEFINED VALUE"
            );
            next;
        }
        $self->$metric($value);
        $self->status_message(
            $self->display_name . " has metric "
            . $metric->name 
            . " with value "
            . $metric->value
        );
    }
}

sub _available_cpu_count {
    my $self = shift; 

    # Not running on LSF, allow only one CPU
    if (!exists $ENV{LSB_MCPU_HOSTS}) {
        return 1;
    }

    my $mval = $ENV{LSB_MCPU_HOSTS};
    my @c = split /\s+/, $mval;

    if (scalar @c != 2) {
        $self->error_message("LSB_MCPU_HOSTS environment variable doesn't specify just one host and one CPU count. (value is '$mval').  Is the span[hosts=1] value set in your resource request?");
        die $self->error_message;
    }

    if ($mval =~ m/(\.*?) (\d+)/) {
        return $2; 
    } else {
        $self->error_message("Couldn't parse the LSB_MCPU_HOSTS environment variable (value is '$mval'). "); 
        die $self->error_message;
    }
    
}


1;
