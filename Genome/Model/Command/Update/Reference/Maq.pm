package Genome::Model::Command::Tools::Reference::Maq;

use strict;
use warnings;

use UR;
use Command;
use IO::File;
use File::Path;
use File::Basename;

UR::Object::Class->define(
    class_name => __PACKAGE__,
    is => 'Command',
    has => [                                # Specify the command's properties (parameters) <--- 
        'fasta'   => { type => 'String',  doc => "required: fasta reference file"},
        'maqdir'   => { type => 'String',  doc => "required: Maq (output) directory"}
    ], 
);

sub help_brief {
    "add a reference sequence for processing with Maq"
}

sub help_detail {                           # This is what the user will see with --help <---
    return <<EOS 
add a reference sequence for processing with Maq
EOS
}

#sub create {                               # Rarely implemented.  Initialize things before execute <---
#    my $class = shift;
#    my %params = @_;
#    my $self = $class->SUPER::create(%params);
#    # ..do initialization here
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
		my($fasta, $maqdir) = 
				 ($self->fasta, $self->maqdir);
		return unless ( defined($fasta) && defined($maqdir)
									);

		$maqdir =~ s/ \/ $ //x;					# Remove any trailing slash

		# Make sure the output directory exists
		unless (-e $maqdir) {
			mkpath $maqdir;
		}

		my $bfa_file = $maqdir . '/' . basename($fasta);
		$bfa_file =~ s/\.fasta/.fa/x;
		$bfa_file =~ s/\.fa/.bfa/x;

		# Convert the reference to the binary fasta format
		system("maq fasta2bfa $fasta $bfa_file");

    return 1;
}

1;


