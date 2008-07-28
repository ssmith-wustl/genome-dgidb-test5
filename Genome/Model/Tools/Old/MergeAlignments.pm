package Genome::Model::Tools::MergeAlignments;

use strict;
use warnings;

use above "Genome";
use Command;

use Fcntl;
use Carp;



UR::Object::Type->define(
    class_name => __PACKAGE__,
    is => 'Command',
    has => ['out','sorted'],                   # Specify the command's properties (parameters) <--- 
);

sub help_brief {
    "Merge one or more packed alignment files into a new, sorted packed alignment file"
}

sub help_detail {                           # This is what the user will see with --help <---
    return <<"EOS"

--out <path_to_alignment_file>  Pathname to use as the prefix for the resulting alignment data and index files
--sorted pathname,pathname,pathname  Comma separated list of alignment files that are already sorted

Any additional command line arguments are taken as unsorted alignment files
EOS
}

#sub create {                               # Rarely implemented.  Initialize things before execute <---
#    my $class = shift;
#    my %params = @_;
#
#    my $self = $class->SUPER::create(%params);
#
#    return $self;
#}

#sub validate_params {                      # Pre-execute checking.  Not requiried <---
#    my $self = shift;
#    return unless $self->SUPER::validate_params(@_);
#    # ..do real checks here
#    return 1;
#}


sub execute {
    my $self = shift;
$DB::single = $DB::stopper;

    require Genome::Model::RefSeqAlignmentCollection;

    my $new_name = $self->out;
    my $new = Genome::Model::RefSeqAlignmentCollection->new(file_prefix => $new_name, mode=> O_RDWR | O_CREAT);
    unless ($new) {
        $self->error_message("Can't create output file $new_name: $!");
        return;
    }

    my @existing;
    foreach my $name ( @{ $self->bare_args } ) {
        my $obj = Genome::Model::RefSeqAlignmentCollection->new(file_prefix => $name);
        unless ($obj) {
            $self->error_message("Can't open alignment file $name: $!");
            return;
        }
				push @existing, ($obj);
    }

		if ($self->sorted) {
			foreach my $name ( split(',',$self->sorted) ) {
        my $obj = Genome::Model::RefSeqAlignmentCollection->new(file_prefix => $name, is_sorted => 1);
        unless ($obj) {
					$self->error_message("Can't open alignment $name: $!");
            return;
        }
				push @existing, ($obj);
			}
		}

    $self->status_message("Merging " . scalar(@existing) . " alignment files into $new_name");
    $new->merge(@existing);
}



1;

