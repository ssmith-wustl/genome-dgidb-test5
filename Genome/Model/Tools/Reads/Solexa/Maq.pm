package Genome::Model::Tools::Old::Reads::Solexa::Maq;

use strict;
use warnings;

use Genome;
use Command;
use IO::File;
use File::Path;
use File::Basename;

UR::Object::Type->define(
    class_name => __PACKAGE__,
    is => 'Command',
    has => [                                # Specify the command's properties (parameters) <--- 
        'gerald'   => { type => 'String',  doc => "Gerald (input) directory"},
        'maqdir'   => { type => 'String',  doc => "Maq (output) directory"},
        'lanes'   => { type => 'String',  doc => "the lanes to process--the default is all: 12345678", is_optional => 1 },
        'keep_fastq'   => { type => 'Boolean',  doc => "keep fastq files", is_optional => 1}
    ], 
);

sub help_brief {
    "add reads from a Gerald directory for processing with Maq"
}

sub help_detail {                           # This is what the user will see with --help <---
    return <<EOS 
add reads from a Gerald directory for processing with Maq
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
		my($geralddir, $maqdir, $lanes) = 
				 ($self->gerald, $self->maqdir, $self->lanes);
		$lanes ||= '12345678';
		return unless ( defined($geralddir) && defined($maqdir)
									);

		$geralddir =~ s/ \/ $ //x;					# Remove any trailing slash
		$maqdir =~ s/ \/ $ //x;					# Remove any trailing slash

		# Make sure the output directory exists
		unless (-e $maqdir) {
			mkpath $maqdir;
		}

		my @geraldfiles = glob($geralddir . '/s_[' . $lanes . ']_sequence.txt*');
		foreach my $seqfile (sort @geraldfiles) {
			my $fastq_file = $maqdir . '/' . basename($seqfile);
			$fastq_file =~ s/\.txt/.fastq/x;
			my $bfq_file = $maqdir . '/' . basename($seqfile);
			$bfq_file =~ s/\.txt/.bfq/x;

			# convert quality values
			system("maq sol2sanger $seqfile $fastq_file");
			# Convert the reads to the binary fastq format
			system("maq fastq2bfq $fastq_file $bfq_file");

			unless ($self->keep_fastq) {
				unlink $fastq_file;
			}
		}
    return 1;
}

1;


