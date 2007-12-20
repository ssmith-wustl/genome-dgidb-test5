
package Genome::Model::Command::Tools::AlignReads::Maq;

use strict;
use warnings;

use above "Genome";
use Command;
use File::Temp;
use IO::File;
use File::Basename;

UR::Object::Type->define(
    class_name => __PACKAGE__,
    is => 'Command',
    has => [                                # Specify the command's properties (parameters) <--- 
        'maqdir'   => { type => 'String',      doc => "maq reads directory"},
        'outmap'   => { type => 'String',      doc => "output map file name"},
        'refbfa'   => { type => 'String',      doc => "reference bfa file"},
        'lanes'   => { type => 'String',  doc => "the lanes to process--the default is all: 12345678", is_optional => 1 },
        'bfq_prefix'   => { type => 'String',  doc => "the prefix to use for bfq files--the default is 's_'", is_optional => 1 },
        'mapfile'   => { type => 'String',     doc => "existing map file to append to", is_optional => 1 },
        'map_opt'   => { type => 'String',     doc => "options to the map step", is_optional => 1 },
        'mapcheck_opt'   => { type => 'String',     doc => "options to the mapcheck step", is_optional => 1 },
        'assemble_opt'   => { type => 'String',     doc => "options to the assemble step", is_optional => 1 },
        'mapcheck'   => { type => 'String',     doc => "mapcheck file name", is_optional => 1 },
        'assemble_log'   => { type => 'String', doc => "assembly log file name", is_optional => 1 },
        'cns_seqq'   => { type => 'String', doc => "consensus sequences and qualities file name", is_optional => 1 },
        'snp'   => { type => 'String', doc => "snp file name", is_optional => 1 },
        'indel'   => { type => 'String', doc => "indel file name", is_optional => 1 }
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

		my($maqdir, $outmap, $refbfa, $lanes, $bfq_prefix) = 
				 ($self->maqdir, $self->outmap, $self->refbfa, $self->lanes, $self->bfq_prefix);
		$lanes ||= '12345678';
		$bfq_prefix ||= 's_';
		return unless ( defined($maqdir) && defined($outmap) && defined($refbfa)
									);

		$maqdir =~ s/ \/ $ //x;					# Remove any trailing slash

		return unless (-e $maqdir);
		return unless (-e $refbfa);

		my $accum_map;
		my $mapfile = $self->mapfile;
		# get $accum_map file name
		$accum_map = tmpnam();
		if (defined($mapfile) && -e $mapfile) {
			show_system("cp $mapfile $accum_map");
		}
		# get $temp1_map file name
		# get $temp2_map file name
		my $temp1_map = tmpnam();
		my $temp2_map = tmpnam();
		print STDERR "Using temporary files: $accum_map $temp1_map $temp2_map\n";
		foreach my $lane (split('',$lanes)) {
			my $bfq_file = $maqdir . '/' . $bfq_prefix . $lane . '_sequence.bfq';
			next unless (-e $bfq_file);
			my $map_opt = ($self->map_opt) ? $self->map_opt : '';
			show_system("maq map $map_opt $temp1_map $refbfa $bfq_file");
			if (-e $accum_map) {
				show_system("mv $accum_map $temp2_map");
				show_system("maq mapmerge $accum_map $temp1_map $temp2_map");
			} else {
				show_system("mv $temp1_map $accum_map");
			}
			if (-e $temp1_map) {
				unlink $temp1_map;
			}
			if (-e $temp2_map) {
				unlink $temp2_map;
			}
		}
		show_system("cp $accum_map $outmap");
		if (-e $accum_map) {
			unlink $accum_map;
		}

		# Statistics from the alignment
		my $mapcheck = $self->mapcheck;
		if (defined($mapcheck)) {
			my $mapcheck_opt = ($self->mapcheck_opt) ? $self->mapcheck_opt : '';
			show_system ("maq mapcheck $mapcheck_opt $refbfa $outmap >$mapcheck");
			show_system ("bzip2 $mapcheck");
		}
		# Build the mapping assembly
		my $outcns = $outmap;
		$outcns =~ s/\.map/.cns/x;
		my $assemble_log = (defined($self->assemble_log)) ? $self->assemble_log : '/dev/null';
		my $assemble_opt = ($self->assemble_opt) ? $self->assemble_opt : '';
		show_system ("maq assemble $assemble_opt $outcns $refbfa $outmap 2>$assemble_log");
		if ($assemble_log ne '/dev/null') {
			show_system ("bzip2 $assemble_log");
		}
		# Extract consensus sequences and qualities
		my $cns_seqq = $self->cns_seqq;
		if (defined($cns_seqq)) {
			show_system("maq cns2fq $outcns >$cns_seqq");
			show_system ("bzip2 $cns_seqq");
		}
		# Extract list of SNPs
		my $outsnp = $self->snp;
		if (defined($outsnp)) {
			show_system("maq cns2snp $outcns >$outsnp");
		}
		# Extract list of SNPs
		my $outindel = $self->indel;
		if (defined($outindel)) {
			show_system("maq indelsoa $refbfa $outmap >$outindel");
		}

    return 1;
}

sub show_system {
  my ($command) = @_;
	print STDERR "$command\n";
	system($command);
}

1;

