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

    # TODO: let the caller do this from any model    
    my $model = Genome::Model->get(name => "NCBI-human");
    my $build = $model->build_by_version("36");
    unless ($build) {
        die "failed to find build 36 Hs?";
    }

    my $cur_chr = 0;
    my $dbsnp_fh;
    my $dbsnp_row;
    my ($variant_position, $variant_allele, $variant_class);

    #assuming we are reasonably sorted
    while (my $line = $snp_fh->getline) {
        chomp $line;
        my ($chr,$pos,) = split /\s+/, $line; 
        
        if($chr ne $cur_chr) {
            # switch to a new chromosome, and open its file
            my $path = $build->data_directory . "/annotation/dbsnp-variations/$chr.dat";
            $dbsnp_fh = IO::File->new($path);
            $dbsnp_row = $dbsnp_fh->getline;
            ($variant_position,$variant_class,$variant_allele) = split(/\s+/,$dbsnp_row);
            $cur_chr = $chr;
            print STDERR "Annotating $cur_chr\n";
        }
       
        # advance to the dbsnp data for this position 
        while($variant_position < $pos) {
            $dbsnp_row = $dbsnp_fh->getline;
            last if not defined $dbsnp_row;
            ($variant_position,$variant_class,$variant_allele) = split(/\s+/,$dbsnp_row);

        };
        
        # if we're at the end of the dbsnp data, move onto the next snp comparison
        last if not defined $dbsnp_row;
        
        # there may be multiple rows of dbsnp data for this position
        # ...just go until we find the first row which represents a snp, not an indel
        while($variant_position == $pos) {   
            if($pos == $variant_position && $variant_class eq 'snp') {
                printf $output_fh "%s\t%d\t%d\t1\n",$chr,$pos,$pos;
                last;
            }
            else {
                $dbsnp_row = $dbsnp_fh->getline;
                last if not defined $dbsnp_row;
                ($variant_position,$variant_class,$variant_allele) = split(/\s+/,$dbsnp_row);
            }
        }
    }

    $dbsnp_fh->close;
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

