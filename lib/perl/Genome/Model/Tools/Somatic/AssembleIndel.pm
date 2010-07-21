package Genome::Model::Tools::Somatic::AssembleIndel;

use strict;
use warnings;

use Genome;
use Genome::Utility::FileSystem;
use IO::File;
use Cwd qw( abs_path );
my $SAM_DEFAULT = Genome::Model::Tools::Sam->default_samtools_version;



class Genome::Model::Tools::Somatic::AssembleIndel {
    is => 'Command',
    has => [
    indel_file =>
    {
        type => 'String',
        is_optional => 0,
        is_input => 1,
        doc => 'Indel sites to assemble in annotator input format',
    },
    bam_file =>
    {
        type => 'String',
        is_optional => 0,
        is_input => 1,
        doc => 'File from which to retrieve reads',
    },
    buffer_size =>
    {
        type => 'Integer',
        is_optional => 1,
        default => 100,
        doc => 'Size in bp around start and end of the indel to include for reads for assembly',
    },
    data_directory =>
    {
        type => 'String',
        is_optional => 0,
        is_input => 1,
        doc => "Location to dump individual chr results etc",
    },
    refseq =>
    {
        type => 'String',
        is_optional => 1,
        default => Genome::Config::reference_sequence_directory() . '/NCBI-human-build36/all_sequences.fasta',
        doc => "reference sequence to use for reference assembly",
    },
    assembly_indel_list =>
    {
       type => 'String',
       is_output=>1,
       doc => "List of assembly results",
   },
   sam_version => {
       is  => 'String',
       doc => "samtools version to be used, default is $SAM_DEFAULT",
       default_value => $SAM_DEFAULT,
       is_optional => 1,
   },
        lsf_resource => {
            is_param => 1,
            default_value => 'rusage[mem=2000] select[type==LINUX64 & mem > 2000] span[hosts=1]',
        },
        lsf_queue => {
            is_param => 1,
            default_value => 'long'
        } 

    ]
};




sub dir_for_chrom {
    my $self=shift;
    my $chr = shift;
    if($chr) {
        return $self->data_directory . "/$chr";
    }
    else {
        return $self->data_directory . "/";
    }
}



sub execute {
    my $self=shift;
    $DB::single = 1;
    
    #test architecture to make sure we can run samtools
    #copied from G::M::T::Maq""Align.t 
    unless (`uname -a` =~ /x86_64/) {
       $self->error_message("Must run on a 64 bit machine");
       return;
    }
    my $bam_file = $self->bam_file;
    unless(-s $bam_file) {
        $self->error_message("$bam_file does not exist or has zero size");
        return;
    }
    my $dir = $self->data_directory;
    unless(-d $dir) {
        $self->error_message("$dir is not a directory");
        return;
    }

    my $refseq = $self->refseq;
    unless(-s $refseq) {
        $self->error_message("$refseq does not exist or has zero size");
        return;
    }


    my $output_file = $self->assembly_indel_list;
    my $output_fh = IO::File->new($output_file, ">");
    unless($output_fh) {
        $self->error_message("Couldn't open $output_file: $!"); 
        return;
    }

    
    my $indel_file = $self->indel_file;
    my $fh = IO::File->new($indel_file, "r");
    unless($fh) {
        $self->error_message("Couldn't open $indel_file: $!"); 
        return;
    }

    my $sam_pathname = Genome::Model::Tools::Sam->path_for_samtools_version($self->sam_version);
    
    while(my $line = $fh->getline) {
        chomp $line;
        $DB::single=1;
        my ($chr, $start, $stop, $ref, $var) = split /\t/, $line;
        my $dir = $self->dir_for_chrom($chr);
        unless(-e $dir) {
            `mkdir -p $dir`;
        }
        next if $chr eq 'chromosome_name';
        if($ref && $ref ne '-' && $var && $var ne '-') {
            $self->error_message("No indel found at $fh->input_line_number. Skipping...");
            next;
        }

        my $region_start = $start - $self->buffer_size;
        my $region_stop = $stop + $self->buffer_size;
        my @reads = `$sam_pathname view $bam_file $chr:$region_start-$region_stop | cut -f1,10`;
        if(@reads) {
            my $prefix = "$dir/${chr}_${start}_${stop}";
            my $read_file = "$prefix.reads.fa";
            my $fa_fh = IO::File->new( $read_file,"w");
            unless($fa_fh) {
                $self->error_message("Unable to open $read_file for writing");
                return;
            }
            foreach my $read (@reads) {
                chomp $read;
                next unless $read;
                my ($readname, $sequence) = split /\t/, $read;
                print $fa_fh ">$readname\n$sequence\n";
            }
            $fa_fh->close;

            #make reference fasta
            my $ref_file = "$prefix.ref.fa";
            my $ref_fh = IO::File->new($ref_file,"w");
            unless($ref_fh) {
                $self->error_message("Unable to open $ref_file for writing");
                return;
            }
            my @contig = `$sam_pathname faidx $refseq $chr:$region_start-$region_stop`;
            if(@contig) {
                print $ref_fh @contig;
            }
            $ref_fh->close;

            `/gsc/scripts/pkg/bio/tigra/installed/local_var_asm_wrapper.sh $read_file`; #assemble the reads
            `cross_match $read_file.contigs.fa $ref_file -bandwidth 20 -minmatch 20 -minscore 25 -penalty -4 -discrep_lists -tags -gap_init -4 -gap_ext -1 > $prefix.stat`;
#            `~kchen/1000genomes/analysis/scripts/hetAtlas.pl -n 100 $read_file.contigs.fa > $read_file.contigs.fa.het`;
#            `cross_match $read_file.contigs.fa.het $ref_file -bandwidth 20 -minmatch 20 -minscore 25 -penalty -4 -discrep_lists -tags -gap_init -4 -gap_ext -1 > $prefix.het.stat`;
#            my ($result) = `~kchen/1000genomes/analysis/scripts/getCrossMatchIndel_ctx.pl -i -s 1 -x ${chr}_${region_start} $prefix.het.stat`; #this should return the crossmatch discrepancy with the highest score
#            if(defined $result && $result =~ /\S+/) {
#                print $result;
#            }
#            else {
                #   print "No assembled indel\n";
                $DB::single=1;
                
                my $cmd = "gmt parse crossmatch --chr-pos ${chr}_${region_start} --crossmatch=$prefix.stat --min-indel-size=1";
                print "$cmd\n";
                my ($stupid_header1, $stupid_header2, $result) = `$cmd`;
                if(defined $result && $result =~ /\S+/) {
                    $output_fh->print($result);
                    print $result . "\n";
                }
                print STDERR "########################\n";

        }
        
    }
        
    return 1;
}


1;

sub help_brief {
    "Scans a snp file and finds adjacent sites. Then identifies if these are DNPs and annotates appropriately."
}

sub help_detail {
    <<'HELP';
    Need to fill in help detail
HELP
}

#copied directly from Ken
sub ComputeTigraN50{
    my ($self,$contigfile)=@_;
    my @sizes;
    my $totalsize=0;
    open(CF,"<$contigfile") || die "unable to open $contigfile\n";
    while(<CF>){
        chomp;
        next unless(/^\>/);
        next if(/\*/);
        my ($id,$size,$depth,$ioc,@extra)=split /\s+/;
        next if($size<=50 && $depth<3 && $ioc=~/0/);
        push @sizes,$size;
        $totalsize+=$size;
    }
    close(CF);
    my $cum_size=0;
    my $halfnuc_size=$totalsize/2;
    my $N50size;
    @sizes=sort {$a<=>$b} @sizes;
    while($cum_size<$halfnuc_size){
        $N50size=pop @sizes;
        $cum_size+=$N50size;
    }
    return $N50size;
}
