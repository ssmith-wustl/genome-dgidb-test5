package Genome::Model::Tools::Old::Genotype::Polybayes;

use strict;
use warnings;

use above "Genome";
use Command;
use File::Path;

UR::Object::Type->define(
    class_name => __PACKAGE__,
    is => 'Command',
    has => [                                # Specify the command's properties (parameters) <--- 
        'sample'   => { type => 'String',  doc => "sample name"},
        'dir'   => { type => 'String',  doc => "Polybayes variation (output) directory"},
        'seqdir'   => { type => 'String',  doc => "sequence (input) directory--defaults to: output_dir/../../sequence", is_optional => 1},
        'alndir'   => { type => 'String',  doc => "alignment (input) directory--defaults to: output_dir/../alignment", is_optional => 1},
        'logdir'   => { type => 'String',  doc => "log (output) directory--defaults to: output_dir/../logs", is_optional => 1},
        'bindir'   => { type => 'String',  doc => "directory for binary executables for polybayes", is_optional => 1},
        'polybayes_opt'   => { type => 'String', doc => "polybayes options--default is: ''", is_optional => 1 }
    ], 
);

sub help_brief {
    "calculate SNPs and Indels using Polybayes"
}

sub help_detail {                           # This is what the user will see with --help <---
    return <<EOS 
calculate SNPs and Indels using Polybayes
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
		my($dir, $sample,
			 $seqdir, $alndir, $logdir, $bindir, $polybayes_opt) =
				 ($self->dir, $self->sample,
					$self->seqdir, $self->alndir, $self->logdir, $self->bindir,
					$self->polybayes_opt);
		$seqdir = RelativeDir($seqdir, 1, $dir, 'sequence', 0);
		$alndir = RelativeDir($alndir, 0, $dir, 'alignment', 0);
		$logdir = RelativeDir($logdir, 0, $dir, 'logs', 1);
		$bindir ||= '/gscmnt/sata114/info/medseq/pkg/bin64';
		return unless ( defined($sample) && defined($dir)
									);
		my $pbshort ||= "$bindir/pbShort";
		my $baa2ace ||= "$bindir/baa2Ace";

		$dir =~ s/ \/ $ //x;					# Remove any trailing slash

		# Make sure the output directory exists
		unless (-e $dir) {
			mkpath $dir;
		}

		show_system("$pbshort --baa $alndir/$sample.baa --bas $seqdir/$sample.bas --tam $dir/$sample.tam --indel --cache 2>/dev/null > $logdir/$sample.log");
		unless (-e "$dir/edit_dir") {
			mkpath "$dir/edit_dir";
		}
		show_system("$baa2ace --baa $alndir/$sample.baa --bas $seqdir/$sample.bas --tam $dir/$sample.tam --ace $dir/edit_dir/$sample.ace");
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

sub show_system {
  my ($command) = @_;
	print STDERR "$command\n";
	system($command);
}

1;
