package Genome::Model::Tools::Simulation::AlterReferenceSequence;

use strict;
use warnings;
use Data::Dumper;
use Genome;           
use Genome::Info::IUB;
our $VERSION = '0.01';

class Genome::Model::Tools::Simulation::AlterReferenceSequence {
    is => 'Command',
    has => [
    ref_fasta => {
        type => 'String',
        is_optional => 0,
        is_input=>1,
    },
    mutation_bed => {
        type => 'String',
        is_optional => 0,
        doc => 'list of mutations in bed format',
    },
    output_file => { 
        type => 'String',
        doc => 'output fasta name. Will generate two files to correctly model diploid, second will have "2"',
    },
    region=> {
        type=>'String',
        is_optional =>0,
        doc =>"restrict the output to a subsection of the input ref",
    },
    ],
};

sub help_brief {
    "Mutates a reference in preparation for read simulation"
}

sub help_detail {
}

sub execute {
    my $self=shift;
    $DB::single=1;

    unless (-s $self->mutation_bed) {
        $self->error_message("mutation_list has no size?");
        return 0;
    }

    my @muts=$self->read_mutation_list($self->mutation_bed);
    unless(@muts) {
        $self->error_message("Able to read mutation list, but returned no valid mutations.");
        return 0;
    }
    my $region = $self->region;
    unless($region) {
        $self->error_message("not yet working on entire genomes, please supply a region");
        return 0;
    }

    my ($refseq, $offset)=$self->read_region_of_fasta($self->region, $self->ref_fasta);
    my $refseq_length= length($refseq);
    my ($out1, $out1_name) =Genome::Sys->create_temp_file();
    #my $out1=IO::File->new($self->output_file, ">");
    my $desc="mutated according to " . $self->mutation_bed;
    $out1->print(">$region-A\t$refseq_length\t$desc\n");
    my ($out2, $out2_name) = Genome::Sys->create_temp_file();
#   my $out2=IO::File->new($self->output_file . "2", ">");
    $out2->print(">$region-B\t$refseq_length\t$desc\n");
    my $pos = $offset;
    my $newrefseq1='';
    my $newrefseq2='';
    foreach my $mut(@muts){
        print "applying";
        print Dumper $mut;
        my $start=$pos-$offset;
        my $len=$mut->{start}-$pos;
        if($mut->{type}=~/SNP/i){
            $len++;
        }
        #my $subseq=unpack("x$start a$len", $refseq);
        my $subseq=substr($refseq,$start,$len);
        next if(length($subseq)!=$len);

        $newrefseq1.=$subseq;
        $newrefseq2.=$subseq;
        $pos+=$len;
#       if($mut->{type}=~/DEL/i){
#           $pos=$mut->{stop};
#       }
#       elsif($mut->{type}=~/INS/i){
#           $newrefseq.=$mut->{variant};
#       }
        if($mut->{type}=~/SNP/i){
            $newrefseq1.=$mut->{variant};
            $newrefseq2.=$mut->{reference};
            $pos++;
        }
        else{

            printf "%s\t%d\t%d\t%d\t%s\n",$mut->{chr},$mut->{start},$mut->{end},$mut->{size},$mut->{type};
            die;
        }
#        $newrefseq1=$self->print_and_flush($newrefseq1, $out1,0);
#        $newrefseq2=$self->print_and_flush($newrefseq2, $out2,0);
    }
    my $start=$pos-$offset;
    my $len=length($refseq)-$start;
    my $subseq=substr($refseq,$start,$len);
    $newrefseq1.=$subseq;
    $newrefseq2.=$subseq;
    $self->print_and_flush($newrefseq1, $out1,1);
    $self->print_and_flush($newrefseq2, $out2,1);
    $out1->close;
    $out2->close;
    my $final_output = $self->output_file;
    if(Genome::Sys->shellcmd(cmd=>"cat $out1_name $out2_name > $final_output")) {
        return 1;
    }
    else {
        return 0;
    }

}

sub print_and_flush {
    my $self = shift;
    my $refseq = shift;
    my $out_fh=shift;
    my $final = shift;

    $refseq =~ s/(.{60})/$1\n/g;
    if($final) {
        $out_fh->print($refseq . "\n");
    }
    else {
        return $refseq;
    }
}


sub read_region_of_fasta {
    my $self = shift;
    my $region = shift;
    my $fasta = shift;
    my ($chr, $start_stop) = split ":", $region;
    my $cmd = "samtools faidx $fasta $region";  #FIXME use the stupid auto samtools version decider at some point
    $self->status_message("ref command: $cmd");
    chomp(my @ref_string = `$cmd`);    
    shift @ref_string;
    my $return_string = join("", @ref_string);
    if($start_stop) {
        my ($start, $stop) = split "-", $start_stop;
        return($return_string, $start);
    }
    return ($return_string, 0);
}

sub read_mutation_list{
    my ($self, $mutlist) = @_;
    my $mut_fh = IO::File->new($mutlist);
    my @muts;
    while(my $line = $mut_fh->getline){
        chomp($line);
        my $mut;
        my ($chr,$start,$stop,$ref_var)=split /\s+/, $line;
        my ($ref, $var) = split "/", $ref_var;
        $mut->{chr}=$chr;
        $mut->{start}=$start;
        $mut->{stop}=$stop;
        $mut->{reference}=$ref;
        $mut->{variant}=$var;
        my $type = $self->infer_variant_type($mut);
        $mut->{type}=$type;
#    print STDERR "$_\n";
        push @muts,$mut;
    }
    return @muts;
}

sub infer_variant_type {
    my ($self,$variant) = @_;

    # If the start and stop are the same, and ref and variant are defined its a SNP
    if (($variant->{stop} == $variant->{start}+1)&&
        ($variant->{reference} ne '-')&&($variant->{reference} ne '0')&&
        ($variant->{variant} ne '-')&&($variant->{variant} ne '0')) {
        return 'SNP';
        # If start and stop are 1 off, and ref and variant are defined its a DNP
    } elsif (($variant->{reference} eq '-')||($variant->{reference} eq '0')) {
        return 'INS';
    } elsif (($variant->{variant} eq '-')||($variant->{variant} eq '0')) {
        return 'DEL';
    } else {
        die("Could not determine variant type from variant:");
    }
}


1;
