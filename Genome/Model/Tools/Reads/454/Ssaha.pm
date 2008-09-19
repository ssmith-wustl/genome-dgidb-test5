package Genome::Model::Tools::Old::Reads::454::Ssaha;

use strict;
use warnings;

use Genome;
use Command;
use File::Path;
use File::Basename;

UR::Object::Type->define(
    class_name => __PACKAGE__,
    is => 'Command',
    has => [                                # Specify the command's properties (parameters) <--- 
        'sample'   => { type => 'String',  doc => "sample name"},
        'sffdir'   => { type => 'String',  doc => "sff (input) directory--default is sff", is_optional => 1},
        'dir'   => { type => 'String',  doc => "sequence (output) directory"},
        'bindir'   => { type => 'String',  doc => "directory for binary executables for ssahaSNP", is_optional => 1},
        'scriptdir'   => { type => 'String',  doc => "directory for script executables for ssahaSNP", is_optional => 1},
        'noflow'   => { type => 'Boolean',  doc => "do not produce flow file", is_optional => 1},
        'nomanifest'   => { type => 'Boolean',  doc => "do not produce manifest file", is_optional => 1}
    ], 
);

sub help_brief {
    "add reads (sff 454 reads) to ssahaSNP"
}

sub help_detail {                           # This is what the user will see with --help <---
    return <<EOS 
add reads (sff 454 reads) to ssahaSNP
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
		my($sample, $sffdir, $dir, $noflow, $nomanifest) = 
				 ($self->sample, $self->sffdir, $self->dir,
					$self->noflow, $self->nomanifest);
		$sffdir ||= 'sff';
		my $sffinfo = 'sffinfo';
		return unless ( defined($sample) && defined($dir)
									);

		my $bindir ||= '/gscmnt/sata114/info/medseq/pkg/bin64';
		my $scriptdir ||= '/gscmnt/sata114/info/medseq/pkg/scripts/bin';
		my $fastq = "$scriptdir/fastq.pl";
		my $compfastq = "$bindir/compFastq";

		$dir =~ s/ \/ $ //x;					# Remove any trailing slash

		# Make sure the output directory exists
		unless (-e $dir) {
			mkpath $dir;
		}

		system("$sffinfo -s $sffdir/$sample.sff > $dir/${sample}_a.fasta");
		system("$sffinfo -q $sffdir/$sample.sff > $dir/${sample}_a.fasta.qual");
		unless ($noflow) {
			system("$sffinfo -f $sffdir/$sample.sff > $dir/$sample.flow");
		}
		unless ($nomanifest) {
			system("$sffinfo -m $sffdir/$sample.sff > $dir/$sample.manifest");
		}

		system("$fastq $dir/${sample}_a.fasta $dir/$sample.fasta");
		system("$compfastq $dir/$sample.fasta.fastq $dir/$sample.fastq");

}

1;


