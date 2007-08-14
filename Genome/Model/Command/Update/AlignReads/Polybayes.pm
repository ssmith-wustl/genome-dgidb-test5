package Genome::Model::Command::AlignReads::Polybayes;

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
        'refseq'   => { type => 'String',      doc => "reference sequence file"},
        'refdir'   => { type => 'String',  doc => "reference (input) directory--default is reference_sequence", is_optional => 1},
        'seqdir'   => { type => 'String',  doc => "sequence (input) directory--defaults to: output_dir/../../sequence", is_optional => 1},
        'logdir'   => { type => 'String',  doc => "log (output) directory--defaults to: output_dir/../../logs", is_optional => 1},
        'bindir'   => { type => 'String',  doc => "directory for binary executables for polybayes", is_optional => 1},
        'bsubscript'   => { type => 'String',  doc => "name of shell script for bsub--not currently used--it would default to sample.sh", is_optional => 1},
        'hashsize'   => { type => 'Integer',  doc => "alignment hash size (10-32)--default is 20", is_optional => 1},
        'alignment_opt'   => { type => 'String', doc => "alignment options--default is: -mmp .02 -minp 0.95 -dp", is_optional => 1 }
    ], 
);

sub help_synopsis {                         # Replace the text below with real examples <---
    return <<EOS
genome-model align-reads maq --refbfa=Reference.bfa --maqdir=./ --outmap=nobel.map --mapfile=existing.map --lanes=123678 --assemble-log=assemble.log --cns-seqq=cns.fq --snp=cures.snp --mapcheck=mapcheck.txt --indel=cures.indel --assemble-opt='-m 3'
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

		my($dir, $sample, $refseq,
			 $refdir, $seqdir, $logdir, $bindir,
			 $bsubscript, $hash_size, $alignment_opt) =
				 ($self->dir, $self->sample, $self->refseq,
					$self->refdir, $self->seqdir, $self->logdir, $self->bindir,
					$self->bsubscript, $self->hashsize, $self->alignment_opt);
		$dir =~ s/ \/ $ //x;					# Remove any trailing slash
		$seqdir = RelativeDir($seqdir, 1, $dir, 'sequence', 0);
		$logdir = RelativeDir($logdir, 1, $dir, 'logs', 1);
		return unless ( defined($dir) && defined($sample) && defined($refseq) &&
										defined($seqdir) && defined($logdir)
									);
		$bindir ||= '/gscmnt/sata114/info/medseq/pkg/binit';
		$refdir ||= 'reference_sequence';
		$bsubscript ||= "$sample.sh";
		$hash_size ||= 20;
		$alignment_opt ||= '-mmp .02 -minp 0.95 -dp';

		# Make sure the output directory exists
		unless (-e $dir) {
			mkpath $dir;
		}
		unless (-e $logdir) {
			mkpath $logdir;
		}
		my $mosaikaligner = "$bindir/MosaikAligner";
		my $mosaikassembler = "$bindir/MosaikAssembler";

		my $reffile;
		if ($refseq !~ /$refdir/xo && $refseq !~ /\.fa/x) {
			$reffile = "$refdir/$refseq.fa";
		} elsif ($refseq !~ /$refdir/xo) {
			$reffile = "$refdir/$refseq";
		} elsif ($refseq !~ /\.fa/x) {
			$reffile = "$refseq.fa";
		} else {
			$reffile = $refseq;
		}

		my $align_cmd = "$mosaikaligner -in $seqdir/$sample.dat -out $dir/${sample}_align.dat -anchors $reffile -oa $dir/$refseq.dat -hs $hash_size $alignment_opt > $logdir/$sample.log";
		my $assemble_cmd = "$mosaikassembler -in $dir/${sample}_align.dat -od $dir -af $dir/$sample.ace -ia $dir/$refseq.dat >> $logdir/$sample.log";
		my $machine = `uname -m`;
		chomp $machine;
		if ($bindir =~ /binit/x && $machine ne 'ia64') {
			bsub_system($bsubscript,'ia64',$align_cmd . "\n" . $assemble_cmd);
		} elsif ($bindir =~ /bin64/x && $machine ne 'x86_64') {
			bsub_system($bsubscript,'x86_64',$align_cmd . "\n" . $assemble_cmd);
		} else {
			show_system($align_cmd);
			show_system($assemble_cmd);
		}

#		my $outsnp = $self->snp;
#		if (defined($outsnp)) {
#			show_system("maq cns2snp $outcns >$outsnp");
#		}
#		# Extract list of SNPs
#		my $outindel = $self->indel;
#		if (defined($outindel)) {
#			show_system("maq indelsoa $refbfa $outmap >$outindel");
#		}

    return 1;
}

sub show_system {
  my ($command) = @_;
	print STDERR "$command\n";
	system($command);
}

sub bsub_system {
  my ($script,$machine,$command) = @_;
	print STDERR "You need to execute on a $machine:\n$command\n";
#	system($command);
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
