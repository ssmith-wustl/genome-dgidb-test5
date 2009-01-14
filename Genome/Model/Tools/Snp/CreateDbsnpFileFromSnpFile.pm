package Genome::Model::Tools::Snp::CreateDbsnpFileFromSnpFile;

use strict;
use warnings;

use Genome;
use Genome::DB::Schema;
use Command;
use IO::File;
use GSCApp;

App->init;
#use Genome::DB::Schema;

class Genome::Model::Tools::Snp::CreateDbsnpFileFromSnpFile {
    is => 'Command',
    has => [
    snp_file => 
    { 
        type => 'String',
        is_optional => 0,
        doc => "Input file of maq cns2snp output for a single individual",
    },
    output_file =>
    {
        type => 'String',
        is_optional => 0,
        doc => "Output file name for dbSNP intersect file",
    },        
    release =>
    {
        type => 'Number',
        is_optional => 1,
        doc => "Release of dbSNP to use",
        default => '129',
    },
    ],
};


sub execute {
    my $self=shift;
    # local $| = 1;
    my $release = $self->release;

    unless(-f $self->snp_file) {
        $self->error_message("Snp file is not a file: " . $self->snp_file);
        return;
    }

    my $snp_fh = IO::File->new($self->snp_file);
    unless($snp_fh) {
        $self->error_message("Failed to open filehandle for: " .  $self->snp_file );
        return;
    }

    my $output_fh = IO::File->new($self->output_file, "w");
    unless($output_fh) {
        $self->error_message("Failed to open filehandle for: " .  $self->output_file );
        return;
    }

    #print output header
    print $output_fh "chromosome\tstart\tend\tdbSNP-129\n";

    #make db connection

    my $dw = GSC::Sequence::Item->dbh;
    my $cur_chr = 0;
    my $cur_chrom_id;
    my $chrom_id = $dw->prepare(qq/
        select seq_id from sequence_item si
        where sequence_item_type = 'chromosome sequence'
            and sequence_item_name = ?
        /);
    my $variation_exists = $dw->prepare(qq/
        select seq2_start,variation_type,allele_description from variation_sequence_tag vs
        join sequence_correspondence scr on scr.scrr_id = vs.vstag_id
        join sequence_collaborator sc on sc.seq_id = vs.vstag_id
        where sc.collaborator_name = 'dbSNP'
            and sc.role_detail = '$release'
            and seq2_start = seq2_stop
            and seq2_id = ? 
        order by seq2_start
        /);

    #Potential Alternate Query worked out by Scott Smith
    #/*+ gives Oracle a 'hint'. Ordering has changed according to tora so this may be faster.
    #
    #select /*+ ordered */ seq2_start,variation_type,allele_description 
    #from sequence_collaborator sc 
    #join sequence_correspondence scr on scr.scrr_id = sc.seq_id 
    #join variation_sequence_tag vs on  vs.vstag_id = vs.vstag_id
    #where sc.collaborator_name = 'dbSNP'
    #and sc.role_detail = '129'
    #and seq2_start = seq2_stop
    #and seq2_id = 1676114023
    #order by seq2_start;
    #
    
    my ($variant_position, $variant_allele, $variant_class);

    #assuming we are reasonably sorted
    while ( my $line = $snp_fh->getline) {
        chomp $line;
        my ($chr,$pos,) = split /\s+/, $line; 
        
        if($chr ne $cur_chr) {
            #retrieve the new chr_id
            $chrom_id->execute('NCBI-human-build36-chrom' . $chr);
            ($cur_chrom_id) = $chrom_id->fetchrow_array;
            next unless(defined($cur_chrom_id));
            $variation_exists->execute($cur_chrom_id);
            $variation_exists->bind_columns(\$variant_position,\$variant_class,\$variant_allele);
            $variation_exists->fetch;
            $cur_chr = $chr;
            print STDERR "Annotating $cur_chr\n";
        }
        
        while($variant_position < $pos && $variation_exists->fetch) {};
        
        while($variant_position == $pos) {   
            if($pos == $variant_position && $variant_class eq 'snp') {
                printf $output_fh "%s\t%d\t%d\t1\n",$chr,$pos,$pos;
                last;
            }
            else {
                last unless $variation_exists->fetch;
            }
        }
    }

    $snp_fh->close; 
    $output_fh->close;

    return 1;
}

1;

sub help_detail {
    return "This module takes a snp list and creates a file of its intersections with dbSNP-129";
}

sub help_brief {
    return "Create a dbSNP/Watson/Venter file";
}

