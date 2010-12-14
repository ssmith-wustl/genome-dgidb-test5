package Genome;

use warnings;
use strict;

# software infrastructure
use UR;

# this keeps available parts of the UR pre-0.01 API we still use
use UR::ObjectV001removed;

# environmental configuration
use Genome::Config;

eval {
    local $SIG{__WARN__};
    local $SIG{__DIE__};
    require Genome::Search;
};

# modules we need to auto-load
use Test::MockObject;
use File::Temp;
use IO::String;

# account for a perl bug in pre-5.10 by applying a runtime patch to Carp::Heavy
use Carp;
use Carp::Heavy;

if ($] < 5.01) {
    no warnings;
    *Carp::caller_info = sub {
        package Carp;
        our $MaxArgNums;
        my $i = shift(@_) + 1;
        package DB;
        my %call_info;
        @call_info{
            qw(pack file line sub has_args wantarray evaltext is_require)
        } = caller($i);

        unless (defined $call_info{pack}) {
            return ();
        }

        my $sub_name = Carp::get_subname(\%call_info);
        if ($call_info{has_args}) {
            # SEE IF WE CAN GET AROUND THE BIZARRE ARRAY COPY ERROR...
            my @args = ();
            if ($MaxArgNums and @args > $MaxArgNums) { # More than we want to show?
                $#args = $MaxArgNums;
                push @args, '...';
            }
            # Push the args onto the subroutine
            $sub_name .= '(' . join (', ', @args) . ')';
        }
        $call_info{sub_name} = $sub_name;
        return wantarray() ? %call_info : \%call_info;
    };
    use warnings;
}


# this ensures that the search system is updated when certain classes are updated 
# the search system is optional so it skips this if usage above fails
if ($INC{"Genome/Search.pm"}) {
    Genome::Search->register_callbacks('UR::Object');
}

# DB::single is set to this value in many places, creating a source-embedded break-point
# set it to zero in the debugger to turn off the constant stopping...
$DB::stopper = 1;

# the standard namespace declaration for a UR namespace
UR::Object::Type->define(
    class_name => 'Genome',
    is => ['UR::Namespace'],
    english_name => 'genome',
);

# Genome supports several environment variables, found under Genome/Env
# Any GENOME_* variable which is set but does NOT corresponde to a module found will cause an exit
# (a hedge against typos such as GENOME_NNNNNO_REQUIRE_USER_VERIFY=1 leading to unexpected behavior)
for my $e (keys %ENV) {
    next unless ($e =~ /^GENOME_/);
    eval "use Genome::Env::$e";
    if ($@) {
        my $path = __FILE__;
        $path =~ s/.pm$//;
        my @files = glob($path . '/Env/*');
        my @vars = map { /Genome\/Env\/(.*).pm/; $1 } @files; 
        print STDERR "Environment variable $e set to $ENV{$e} but there were errors using Genome::Env::$e:\n"
        . "Available variables:\n\t" 
        . join("\n\t",@vars)
        . "\n";
        exit 1;
    }
}

1;

=pod

=head1 NAME

Genome - the namespace for genome analysis and modeling 

=head1 SYNOPSIS

use Genome;

# modules in the genome namespace will now dynamically load

 $m = Genome::Model->get(...);

=head1 BUGS

For defects with any software in the genome namespace,
contact software@genome.wustl.edu.

=head1 SEE ALSO

B<Genome::Model>, B<Genome::Model::Tools>

B<Genome::Taxon>, B<Genome::PopulationGroup>, B<Genome::Individual>,
B<Genome::Sample>, B<Genome::Library>, B<Genome::InstrumentData>

=cut

