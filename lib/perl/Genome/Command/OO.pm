package Genome::Command::OO;
use strict;
use warnings;
use Genome;

class Genome::Command::OO {
    class_name => __PACKAGE__,    
    is => 'Command',
    is_abstract => 1, 
};

sub _shell_args_property_meta {
    my $self = shift;
    my $class_meta = $self->__meta__;
    my @property_meta = $class_meta->get_all_property_metas(@_);
    my @result;
    my %seen;
    my (@positional,@required,@optional);
    for my $property_meta (@property_meta) {
        my $property_name = $property_meta->property_name;
        next if $property_name eq 'id';
        next if $property_name eq 'result';
        next if $property_name eq 'is_executed';
        next if $property_name =~ /^_/;
        next if $property_meta->implied_by;
        next if $property_meta->is_calculated;
        #next if $property_meta->{is_output}; # TODO: This was breaking the G::M::T::Annotate::TranscriptVariants annotator. This should probably still be here but temporarily roll back
        next if $property_meta->is_transient;
        next if $seen{$property_name};
        if ($property_meta->is_delegated or (defined($property_meta->data_type) and $property_meta->data_type =~ /::/)) {
            my $class = $property_meta->data_type;
            unless ($class->can("from_cmdline")) {
                next;
            }
        }
        elsif (not $property_meta->is_mutable) {
            next;
        }
        $seen{$property_name} = 1;
        next if $property_meta->is_constant;
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
    
    @result = ( 
        (sort { $a->property_name cmp $b->property_name } @required),
        (sort { $a->property_name cmp $b->property_name } @optional),
        (sort { $a->{shell_args_position} <=> $b->{shell_args_position} } @positional),
    );
    
    return @result;
}

sub resolve_class_and_params_for_argv {
    my $self = shift;
    my ($class, $params) = $self->SUPER::resolve_class_and_params_for_argv(@_);
    if ($params) {
        my $cmeta = $self->__meta__;
        for my $param (keys %$params) {
            my $pmeta = $cmeta->property($param); 
            unless ($pmeta) {
                next;
                die "not meta for $param?";
            }
            my $type = $pmeta->data_type;
            next unless $type;
            next unless $type->can("from_cmdline");
            my $value = $params->{$param};
            my @obj;
            if (ref($value)) {
                @obj = $type->from_cmdline(@$value); 
            }
            else { 
                eval { $obj[0] = $type->from_cmdline($value); };
                if ($@ and $@ =~ /Multiple (?:results|matches)/) {
                    $self->error_message("$param matches multiple values!");
                    @obj = $type->from_cmdline($value);
                    $self->error_message(
                        join('',
                            map { "\n\t" . $_->__display_name__ } 
                            @obj
                        )
                    );
                    return ($class, undef);
                }
            }
            my $value_str = (ref($value) ? join(", ", @$value)  : $value);
            if ($@) {
                $self->error_message("problems resolving $param from $value_str");
                return ($class, undef);
            }
            unless (@obj and $obj[0]) {
                $self->error_message("Failed to find $param for $value_str!");
                return ($class, undef);
            }
            if (ref($value)) {
                @$value = @obj;
            }
            else {
                $params->{$param} = $obj[0];
            }
        }
    }
    return ($class, $params);
}

sub default_cmdline_selector {
    my $class = shift;
    my @obj;
    while (my $txt = shift) {
        eval {
            my $bx = UR::BoolExpr->resolve_for_string($class,$txt);
            my @matches = $class->get($bx);
            push @obj, @matches;
        };
        if ($@) {
            my @matches = $class->get($txt);
            push @obj, @matches;
        }
    }

    if (wantarray) {
        return @obj;
    }
    elsif (not defined wantarray) {
        return;
    }
    elsif (@obj > 1) {
        Carp::confess("Multiple matches found!");
    }
    else {
        return $obj[0];
    }
}

sub X_shell_arg_getopt_specification_from_property_meta {
    my ($self,$property_meta) = @_;
    my $arg_name = $self->_shell_arg_name_from_property_meta($property_meta);
    my @spec_value;
    if (my $type = $property_meta->data_type) {
        if (my $code = $type->can("from_cmdline")) {
            @spec_value = (
                $arg_name => sub { print ">>@_<<\n"; $type->from_cmdline(@_) }
            );    
        }
    }
    if ($property_meta->is_many and not @spec_value) {
        @spec_value = ($arg_name => []);
    }
    return (
        $arg_name .  $self->_shell_arg_getopt_qualifier_from_property_meta($property_meta),
        @spec_value
    );
}

sub _ask_user_question {
    my $self = shift;
    my $question = shift;
    my $timeout = shift || 60;
    my $input;
    eval {
        local $SIG{ALRM} = sub { die "Failed to reply to question '$question' with in '$timeout' seconds\n" };
        $self->status_message($question);
        $self->status_message("Please reply: 'yes' or 'no'");
        alarm($timeout);
        chomp($input = <STDIN>);
        alarm(0);
    };
    if ($@) {
        $self->warning_message($@);
        return;
    }
    unless ($input =~ m/yes|no/) {
        $self->error_message("'$input' is an invalid answer to question '$question'");
        return;
    }
    return $input;
}


1;

