package Genome::Model::Command::AlignReads::Ssahasnp;

use strict;
use warnings;

use UR;
use Command;
use File::Path;
use File::Basename;

UR::Object::Class->define(
    class_name => __PACKAGE__,
    is => 'Command',
    has => [                                # Specify the command's properties (parameters) <--- 
        'sample'   => { type => 'String',  doc => "sample name"},
        'dir'   => { type => 'String',  doc => "alignment (output) directory"},
        'sample'   => { type => 'String',  doc => "sample name"},
        'refseq'   => { type => 'String',  doc => "reference sequence file"},
        'seqdir'   => { type => 'String',  doc => "sequence (input) directory--defaults to: output_dir/../../sequence", is_optional => 1},
        'alignment_opt'   => { type => 'String', doc => "alignment options--default is: -454 -memory=6000", is_optional => 1 },
        'logfile'   => { type => 'String', doc => "logfile--default is none", is_optional => 1 },
        'bindir'   => { type => 'String',  doc => "directory for binary executables for ssahaSNP", is_optional => 1}
    ], 
);

sub help_synopsis {                         # Replace the text below with real examples <---
    return <<EOS
genome-model align-reads ssahasnp --dir=ssahaSNP/ccds/alignment --refseq=reference_sequence/CCDS_nucleotide.20070227.fa --sample=H_GW-454_EST_S_8977 --logfile=ssahaSNP/ccds/logs/H_GW_454_EST_S_8977.log
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

		my($dir, $sample, $seqdir, $refseq, $alignment_opt, $logfile, $bindir) =
				 ($self->dir, $self->sample, $self->seqdir, $self->refseq,
					$self->alignment_opt, $self->logfile, $self->bindir);
		$seqdir = RelativeDir($seqdir, 1, $dir, 'sequence', 0);
		return unless ( defined($dir) && defined($sample) && 
										defined($seqdir) && defined($refseq)
									);

		$bindir ||= '/gscmnt/sata114/info/medseq/pkg/bin64';
		$alignment_opt ||= '-454 -memory=6000';

		my $ssahasnp = "$bindir/ssahaSNP";

		$dir =~ s/ \/ $ //x;					# Remove any trailing slash

		# Make sure the output directory exists
		unless (-e $dir) {
			mkpath $dir;
		}

		my $align_cmd = "$ssahasnp $seqdir/$sample.fastq $refseq $alignment_opt > $dir/$sample.out";
		if (defined($logfile)) {
			my $logdir = dirname($logfile);
			$logdir =~ s/ \/ $ //x;					# Remove any trailing slash

			# Make sure the output directory exists
			unless (-e $logdir) {
				mkpath $logdir;
			}
			show_system("$align_cmd 2> $logfile");
		} else {
			show_system($align_cmd);
		}

    return 1;
}

sub show_system {
  my ($command) = @_;
	print STDERR "$command\n";
	system($command);
}

sub RelativeDir {
	my ($outdir, $numpop, $dir, $reldir, $new) = @_;
	if (!defined($outdir)) {
		my @tmpdir = split('/',$dir);
		for (my $i = 0;$i <= $numpop;$i++) {
			pop @tmpdir;
		}
		push @tmpdir, ($reldir);
		my $tmprel = join('/',@tmpdir);
		if ($new || -e $tmprel) {
			$outdir = $tmprel;
		}
	}
	return $outdir;
}

1;
