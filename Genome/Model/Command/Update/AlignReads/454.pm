package Genome::Model::Command::Update::AlignReads::454;

use strict;
use warnings;

use UR;
use Command;
use File::Path;

UR::Object::Class->define(
    class_name => __PACKAGE__,
    is => 'Command',
    has => [                                # Specify the command's properties (parameters) <--- 
        'sample'   => { type => 'String',  doc => "sample name"},
        'sffdir'   => { type => 'String',  doc => "sff (input) directory--default is sff", is_optional => 1},
        'dir'   => { type => 'String',  doc => "project alignment (output) directory"},
        'refseq'   => { type => 'String',      doc => "reference sequence file"},
				'options' => { type => 'String', doc => "runMapping options", is_optional => 1}
    ], 
);

sub help_synopsis {                         # Replace the text below with real examples <---
    return <<EOS
genome-model align-reads 454 --dir=454/ccds/alignment --refseq=reference_sequence/CCDS_nucleotide.20070227.fa --sample=H_GW-454_EST_S_8977
EOS
}

sub help_brief {
    "launch the aligner for a given set of new reads"
}

sub help_detail {                       
    return <<EOS 


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

		my($dir, $sample, $sffdir, $refseq, $options) = 
				 ($self->dir, $self->sample, $self->sffdir, $self->refseq, $self->options);
		$options ||= '';
		return unless ( defined($dir) &&
										defined($sample) && defined($refseq)
									);

		$sffdir ||= 'sff';
		$dir =~ s/ \/ $ //x;				# Remove any trailing slash

		# Make sure the output directory exists
		unless (-e $dir) {
			mkpath $dir;
		}

		show_system("runMapping -o $dir $options $refseq $sffdir/$sample.sff");

    return 1;
}

sub show_system {
  my ($command) = @_;
	print STDERR "$command\n";
	system($command);
}

1;

