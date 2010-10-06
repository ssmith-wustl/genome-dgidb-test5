package Genome::Command::Base;

use strict;
use warnings;

use Genome;

use Data::Dumper;
require File::Basename;

class Genome::Command::Base {
    is => 'Command',
    is_abstract => 1,
    attributes_have => [
        require_user_verify => {
            is => 'Boolean',
            is_optional => 1,
            # 0 = prevent verify, 1 = force verify, undef = allow auto verify
        },
    ],
};

our %ALTERNATE_FROM_CLASS = (
    # find_class => via_class => via_class_methods
    # first method is the default method
    # the default method is used automatically if not the paramater
    # data type so it should be the most verbose option
    'Genome::InstrumentData' => {
        'Genome::Model' => ['instrument_data'],
        'Genome::Model::Build' => ['instrument_data'],
    },                        
    'Genome::Model' => {
        'Genome::Model::Build' => ['model'],
        'Genome::ModelGroup' => ['models'],
    },
    'Genome::Model::Build' => {
        'Genome::Model' => ['builds', 'latest_build', 'last_successful_build', 'running_builds'],
    },
);
# This will prevent infinite loops during recursion.
our %SEEN_FROM_CLASS = ();

our $MESSAGE;

sub resolve_param_value_from_cmdline_text {
    my ($self, $param_name, $param_class, $param_arg) = @_;

    my @param_args = split(',', $param_arg);
    my @param_class;
    if (ref($param_class) eq 'ARRAY') {
        @param_class = @$param_class;
    }
    else {
        @param_class = ($param_class);
    }
    undef($param_class);
    if (@param_args > 1) {
        my %bool_expr_type_count;
        my @bool_expr_type = map {split(/[=~]/, $_)} @param_args;
        for my $type (@bool_expr_type) {
            $bool_expr_type_count{$type}++;
        }
        my $duplicate_bool_expr_type = 0;
        for my $type (keys %bool_expr_type_count) {
            $duplicate_bool_expr_type++ if ($bool_expr_type_count{$type} > 1);
        }
        @param_args = (join(',', @param_args), @param_args) unless($duplicate_bool_expr_type);
    }

    my @results;
    my $force_verify = 0;
    for (my $i = 0; $i < @param_args; $i++) {
        my $arg = $param_args[$i];
        my @arg_results;
        (my $arg_display = $arg) =~ s/,/ AND /g; 
        $self->status_message("Looking for parameters using '$arg_display'...");

        for my $param_class (@param_class) {
            #$self->debug_message("Trying to find $param_class...");
            %SEEN_FROM_CLASS = ();
            # call resolve_param_value_from_text without a via_method to bootstrap recursion
            @arg_results = $self->resolve_param_value_from_text($arg, $param_class);
        } 

        $force_verify = 1 if (@arg_results > 1);
        if (@arg_results) {
            push @results, @arg_results;
            last if ($arg =~ /,/); # the first arg is all param_args as BoolExpr, if it returned values finish; basically enforicing AND (vs. OR)
        }
        elsif ( $i != 0 || @param_args == 1 ) {
            print STDERR "WARNING: No match found for $arg!\n";
        }
    }

    return unless (@results);

    @results = $self->_unique_elements(@results);
    my $pmeta = $self->__meta__->property($param_name);
    unless (defined($pmeta->{'require_user_verify'}) && $pmeta->{'require_user_verify'} == 0) {
        if ($pmeta->{'require_user_verify'} || $force_verify) {
            @results = $self->_get_user_verification_for_param_value(@results);
        }
    }
    while (!$pmeta->{'is_many'} && @results > 1) {
        $self->error_message("$param_name expects one result, not many!");
        @results = $self->_get_user_verification_for_param_value(@results);
    }

    if (wantarray) {
        return @results;
    }
    elsif (not defined wantarray) {
        return;
    }
    elsif (@results > 1) {
        Carp::confess("Multiple matches found!");
    }
    else {
        return $results[0];
    }
}

sub resolve_param_value_from_text {
    my ($self, $param_arg, $param_class, $via_method) = @_;

    unless ($param_class) {
        $param_class = $self->class;
    }

    $SEEN_FROM_CLASS{$param_class} = 1;
    my @results;
    # try getting BoolExpr, otherwise fallback on '_resolve_param_value_from_text_by_name_or_id' parser
    eval { @results = $self->_resolve_param_value_from_text_by_bool_expr($param_class, $param_arg); };
    # the first param_arg is all param_args to try BoolExpr so skip if it has commas
    if (!@results && $param_arg !~ /,/) {
        my @results_by_string;
        if ($param_class->can('_resolve_param_value_from_text_by_name_or_id')) {
            @results_by_string = $param_class->_resolve_param_value_from_text_by_name_or_id($param_arg);
        }
        else {
            @results_by_string = $self->_resolve_param_value_from_text_by_name_or_id($param_class, $param_arg); 
        }
        push @results, @results_by_string;
    }
    # if we still don't have any values then try via alternate class
    if (!@results && $param_arg !~ /,/) {
        @results = $self->_resolve_param_value_via_related_class_method($param_class, $param_arg, $via_method);
    }

    if ($via_method) {
        @results = map { $_->$via_method } @results;
    }

    if (wantarray) {
        return @results;
    }
    elsif (not defined wantarray) {
        return;
    }
    elsif (@results > 1) {
        Carp::confess("Multiple matches found!");
    }
    else {
        return $results[0];
    }
}

sub _resolve_param_value_via_related_class_method {
    my ($self, $param_class, $param_arg, $via_method) = @_;
    my @results;
    my $via_class;
    if (exists($ALTERNATE_FROM_CLASS{$param_class})) {
        $via_class = $param_class;
    }
    else {
        for my $class (keys %ALTERNATE_FROM_CLASS) {
            if ($param_class->isa($class)) {
                if ($via_class) {
                    $self->error_message("Found additional via_class $class but already found $via_class!");
                }
                $via_class = $class;
            }
        }
    }
    if ($via_class) {
        my @from_classes = sort keys %{$ALTERNATE_FROM_CLASS{$via_class}};
        while (@from_classes && !@results) {
            my $from_class  = shift @from_classes;
            my @methods = @{$ALTERNATE_FROM_CLASS{$via_class}{$from_class}};
            my $method;
            if (@methods > 1 && !$via_method) {
                $self->status_message("Trying to find $via_class via $from_class...\n");
                my $method_choices;
                for (my $i = 0; $i < @methods; $i++) {
                    $method_choices .= ($i + 1) . ": " . $methods[$i];
                    $method_choices .= " [default]" if ($i == 0);
                    $method_choices .= "\n";
                }
                $method_choices .= (scalar(@methods) + 1) . ": none\n";
                $method_choices .= "Which method would you like to use?";
                my $response = $self->_ask_user_question($method_choices, 300, '\d+', 1, '#');
                if ($response =~ /^\d+$/) {
                    $response--;
                    if ($response == @methods) {
                        $method = undef;
                    }
                    elsif ($response >= 0 && $response <= $#methods) {
                        $method = $methods[$response];
                    }
                    else {
                        $self->error_message("Response was out of bounds, exiting...");
                        exit;
                    }
                    $ALTERNATE_FROM_CLASS{$via_class}{$from_class} = [$method];
                }
                elsif (!$response) {
                    $self->status_messag("Exiting...");
                }
            }
            else {
                $method = $methods[0];
            }
            unless($SEEN_FROM_CLASS{$from_class}) {
                #$self->debug_message("Trying to find $via_class via $from_class->$method...");
                @results = $self->resolve_param_value_from_text($param_arg, $from_class, $method);
            }
        } # END for my $from_class (@from_classes)
    } # END if ($via_class)
    return @results;
}

sub _resolve_param_value_from_text_by_bool_expr {
    my ($self, $param_class, $arg) = @_;

    my @results;
    my $bx;
    eval {
        $bx = UR::BoolExpr->resolve_for_string($param_class, $arg);
    };
    unless ($@) {
        @results = $param_class->get($bx);
    }
    #$self->debug_message("B: $param_class '$arg' " . scalar(@results));

    return @results;
}

sub _resolve_param_value_from_text_by_name_or_id {
    my ($self, $param_class, $str) = @_;
    my (@results);
    if ($str =~ /^-?\d+$/) { # try to get by ID
        @results = $param_class->get($str);
    }
    if (!@results && $param_class->can('name')) {
        @results = $param_class->get(name => $str);
        unless (@results) {
            @results = $param_class->get("name like" => "$str");
        }
    }
    #$self->debug_message("S: $param_class '$str' " . scalar(@results));

    return @results;
}

sub _get_user_verification_for_param_value {
    my ($self, @list) = @_;

    my $n_list = scalar(@list);
    if ($n_list > 20) {
        my $response = $self->_ask_user_question("Would you [v]iew all $n_list item(s), (p)roceed, or e(x)it?", 300, '[v]|p|x', 'v');
        if(!$response || $response eq 'x') {
            $self->status_message("Exiting...");
            exit;
        }
        return @list if($response eq 'p');
    }

    my @new_list;
    while (!@new_list) {
        @new_list = $self->_get_user_verification_for_param_value_drilldown(@list);
    }

    my @ids = map { $_->id } @new_list;
    $self->status_message("The IDs for your selection are:\n" . join(',', @ids) . "\n\n");
    return @new_list;
}
sub _get_user_verification_for_param_value_drilldown {
    my ($self, @results) = @_;
    my $n_results = scalar(@results);
    my $pad = length($n_results);

    # Allow an environment variable to be set to disable the require_user_verify attribute
    return @results if ($ENV{GENOME_NO_REQUIRE_USER_VERIFY});
    return if (@results == 0);

    my @dnames = map {$_->__display_name__} grep { $_->can('__display_name__') } @results;
    my $max_dname_length = @dnames ? length((sort { length($b) <=> length($a) } @dnames)[0]) : 0;
    my @statuses = map {$_->status} grep { $_->can('status') } @results;
    my $max_status_length = @statuses ? length((sort { length($b) <=> length($a) } @statuses)[0]) : 0;
    @results = sort {$a->__display_name__ cmp $b->__display_name__} @results;
    @results = sort {$a->class cmp $b->class} @results;
    my @classes = $self->_unique_elements(map {$_->class} @results);

    $self->status_message("Found $n_results match(es):");
    my $response;
    while (!$response) {
        # TODO: Replace this with lister?
        for (my $i = 1; $i <= $n_results; $i++) {
            my $param = $results[$i - 1];
            my $num = $self->_pad_string($i, $pad);
            my $msg = "$num:";
            $msg .= ' ' . $self->_pad_string($param->__display_name__, $max_dname_length, 'suffix');
            my $status = ' ';
            if ($param->can('status')) {
                $status = $param->status;
            }
            $msg .= "\t" . $self->_pad_string($status, $max_status_length, 'suffix');
            $msg .= "\t" . $param->class if (@classes > 1);
            $self->status_message($msg);
        }
        if ($MESSAGE) {
            $MESSAGE = '*'x80 . "\n" . $MESSAGE . "\n" . '*'x80 . "\n";
            $self->status_message($MESSAGE);
            $MESSAGE = '';
        }
        $response = $self->_ask_user_question("Proceed using the above list?", 300, '\*|y|b|h|x|[-+]?[\d\-\., ]+', 'h', '(y)es|(b)ack|(h)elp|e(x)it|LIST');
        if (lc($response) eq 'h' || !$self->_validate_user_response_for_param_value_verification($response)) {
            $MESSAGE .= "\n" if ($MESSAGE);
            $MESSAGE .=
            "Help:\n".
            "* Specify which elements to keep by listing them, e.g. '1,3,12' would keep items 1, 3, and 12.\n".
            "* Begin list with a minus to remove elements, e.g. '-1,3,9' would remove items 1, 3, and 9.\n".
            "* Ranges can be used, e.g. '-11-17, 5' would remove items 11 through 17 and remove item 5.";
            $response = '';
        }
    }
    if (lc($response) eq 'x') {
        $self->status_message("Exiting...");
        exit;
    }
    elsif (lc($response) eq 'b') {
        return;
    }
    elsif (lc($response) eq 'y' | $response eq '*') {
        return @results;
    }
    elsif ($response =~ /^[-+]?[\d\-\., ]+$/) {
        @results = $self->_trim_list_from_response($response, @results);
        return @results;
    }
    else {
        die $self->error_message("Conditional exception, should not have been reached!");
    }
}

sub _validate_user_response_for_param_value_verification {
    my ($self, $response_text) = @_;
    $response_text = substr($response_text, 1) if ($response_text =~ /^[+-]/);
    my @response = split(/[\s\,]/, $response_text);
    for my $response (@response) {
        if ($response =~ /^[xby*]$/) {
            return 1;
        }
        if ($response !~ /^(\d+)([-\.]+(\d+))?$/) {
            $MESSAGE .= "\n" if ($MESSAGE);
            $MESSAGE .= "ERROR: Invalid list provided ($response)";
            return 0;
        }
        if ($3 && $1 && $3 < $1) {
            $MESSAGE .= "\n" if ($MESSAGE);
            $MESSAGE .= "ERROR: Inverted range provided ($1-$3)";
            return 0;
        }
    }
    return 1;
}

sub _trim_list_from_response {
    my ($self, $response_text, @list) = @_;

    my $method;
    if ($response_text =~ /^[+-]/) {
        $method = substr($response_text, 0, 1);
        $response_text = substr($response_text, 1);
    }
    else {
        $method = '+';
    }

    my @response = split(/[\s\,]/, $response_text);
    my %indices;
    @indices{0..$#list} = 0..$#list if ($method eq '-');

    for my $response (@response) {
        $response =~ /^(\d+)([-\.]+(\d+))?$/;
        my $low = $1; $low--;
        my $high = $3 || $1; $high--;
        die if ($high < $low);
        if ($method eq '+') {
            @indices{$low..$high} = $low..$high;
        }
        else {
            delete @indices{$low..$high};
        }
    }
    #$self->debug_message("Indices: " . join(',', sort(keys %indices)));
    my @new_list = $self->_get_user_verification_for_param_value_drilldown(@list[sort keys %indices]);
    unless (@new_list) {
        @new_list = $self->_get_user_verification_for_param_value_drilldown(@list);
    }
    return @new_list;
}

sub _pad_string {
    my ($self, $str, $width, $pos) = @_;
    my $padding = $width - length($str);
    $padding = 0 if ($padding < 0);
    if ($pos && $pos eq 'suffix') {
        return $str . ' 'x$padding;
    }
    else {
        return ' 'x$padding . $str;
    }
}

sub _shell_args_property_meta
{
    my $self = shift;
    my $class_meta = $self->__meta__;

    # Find which property metas match the rules.  We have to do it this way
    # because just calling 'get_all_property_metas()' will product multiple matches 
    # if a property is overridden in a child class
    my $rule = UR::Object::Property->define_boolexpr(@_);
    my %seen;
    my (@positional,@required,@optional);
    foreach my $property_meta ( $class_meta->get_all_property_metas() ) {
        my $property_name = $property_meta->property_name;

        next if $seen{$property_name}++;
        next unless $rule->evaluate($property_meta);

        next if $property_name eq 'id';
        next if $property_name eq 'result';
        next if $property_name eq 'is_executed';
        next if $property_name =~ /^_/;

        next if $property_meta->implied_by;
        next if $property_meta->is_calculated;
        # Kept commented out from UR's Command.pm, I believe is_output is a workflow property
        # and not something we need to exclude (counter to the old comment below).
        #next if $property_meta->{is_output}; # TODO: This was breaking the G::M::T::Annotate::TranscriptVariants annotator. This should probably still be here but temporarily roll back
        next if $property_meta->is_transient;
        next if $property_meta->is_constant;
        if (($property_meta->is_delegated) || (defined($property_meta->data_type) and $property_meta->data_type =~ /::/)) {
            next unless($self->can('resolve_param_value_from_cmdline_text'));
        }
        else {
            next unless($property_meta->is_mutable);
        }
        if ($property_meta->{shell_args_position}) {
            push @positional, $property_meta;
        }
        elsif ($property_meta->is_optional) {
            push @optional, $property_meta;
        }
        else {
            push @required, $property_meta;
        }
    }
    
    my @result;
    @result = ( 
        (sort { $a->property_name cmp $b->property_name } @required),
        (sort { $a->property_name cmp $b->property_name } @optional),
        (sort { $a->{shell_args_position} <=> $b->{shell_args_position} } @positional),
    );
    
    return @result;
}

sub _check_for_missing_parameters {
    my ($self, $params) = @_;

    my $class_object = $self->__meta__;
    my $type_name = $class_object->type_name;

    my @property_names;
    my $class_meta = UR::Object::Type->get($self);
    if (my $has = $class_meta->{has}) {
        push @property_names, keys %$has;
    }
    @property_names = $self->_unique_elements(@property_names);

    my @property_metas = map { $class_object->property_meta_for_name($_); } @property_names;

    my @missing_property_values;
    for my $property_meta (@property_metas) {
        next if $property_meta->is_optional;
        next if $property_meta->implied_by;
        my $property_name = $property_meta->property_name;
        my $property_value_defined = defined($params->{$property_name}) || defined($property_meta->default_value);
        if ($property_value_defined) {
            next;
        }
        else {
            push @missing_property_values, $property_name;
        }
    }

    @missing_property_values = map { $_ =~ s/_/-/g; $_ } @missing_property_values;
    @missing_property_values = map { $_ =~ s/^/--/g; $_ } @missing_property_values;
    if (@missing_property_values) {
        $self->status_message('');
        $self->error_message("Missing required parameter(s): " . join(', ', @missing_property_values) . ".");
        return 0;
    }
    else {
        return 1;
    }
}

sub resolve_class_and_params_for_argv {
    my $self = shift;
    my ($class, $params) = $self->SUPER::resolve_class_and_params_for_argv(@_);
    unless ($self eq $class) {
        return ($class, $params);
    }
    unless (@_ && $self->_check_for_missing_parameters($params)) {
        $params->{help} = 1;
        return ($class, $params);
    }
    
    if ($params) {
        my $cmeta = $self->__meta__;
        for my $param_name (keys %$params) {
            my $pmeta = $cmeta->property($param_name); 
            unless ($pmeta) {
                next;
                die "not meta for $param_name?";
            }

            my $param_type = $pmeta->data_type;
            next unless ($param_type);
            if (ref($param_type) eq 'ARRAY') {
                for my $sub_type (@$param_type) {
                    next unless ($sub_type =~ /::/);
                }
            }
            else {
                next unless ($param_type =~ /::/);
            }

            my $param_arg = $params->{$param_name};
            my @param_args;
            if (ref($param_arg) eq 'ARRAY') {
                @param_args = @$param_arg;
            }
            elsif (ref($param_arg)) {
                $self->error_message("no handler for param_arg of type " . ref($param_arg));
                next;
            }
            else {
                @param_args = ($param_arg);
            }
            next unless (@param_args);
            my $param_arg_str = join(',', @param_args);

            my @params;
            eval {
                @params = $self->resolve_param_value_from_cmdline_text($param_name, $param_type, $param_arg_str);
            };
            

            if ($@) {
                $self->error_message("problems resolving $param_name from $param_arg_str: $@");
                return ($class, undef);
            }
            unless (@params and $params[0]) {
                $self->error_message("Failed to find $param_name for $param_arg_str!");
                return ($class, undef);
            }

            if ($pmeta->{'is_many'}) {
                $params->{$param_name} = \@params;
            }
            else {
                $params->{$param_name} = $params[0];
            }
        }
    }
    return ($class, $params);
}

sub _ask_user_question {
    my $self = shift;
    my $question = shift;
    my $timeout = shift || 60;
    my $valid_values = shift || "yes|no";
    my $default_value = shift || undef;
    my $pretty_valid_values = shift || $valid_values;
    $valid_values = lc($valid_values);
    my $input;
    eval {
        local $SIG{ALRM} = sub { print STDERR "Exiting, failed to reply to question '$question' within '$timeout' seconds.\n"; exit; };
        print STDERR "$question\n";
        print STDERR "Please reply with $pretty_valid_values: ";
        alarm($timeout);
        chomp($input = <STDIN>);
        alarm(0);
    };
    print STDERR "\n";

    if ($@) {
        $self->warning_message($@);
        return;
    }
    if(lc($input) =~ /^$valid_values$/) {
        return lc($input);
    }
    elsif ($default_value) {
        return $default_value;
    }
    else {
        $self->error_message("'$input' is an invalid answer to question '$question'\n\n");
        return;
    }
}

sub _unique_elements {
    my ($self, @list) = @_;
    my %seen = ();
    my @unique = grep { ! $seen{$_} ++ } @list;
    return @unique;
}

1;

#$HeadURL$
#$Id$

