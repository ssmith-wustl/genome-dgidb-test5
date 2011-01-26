package Genome::Model::Tools::Snp::CreateDbsnpFileFromSnpFile;

use strict;
use warnings;

use Genome;
use Command;
use IO::File;
#use GSCApp;

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

sub create {
	my $class = shift;
	my $self = $class->SUPER::create(@_);
	return undef unless $self;

	unless (Genome::Sys->validate_file_for_reading($self->snp_file)) {
		$self->error_message('Failed to validate snp file '. $self->snp_file .' for reading');
		return;
	}	
	unless (Genome::Sys->validate_file_for_writing($self->output_file)) {
		$self->error_message('Failed to validate output file '. $self->output_file .' for writing');
		return;
	}
	return $self;
}


sub execute {
    my $self=shift;
    # local $| = 1;
    my $release = $self->release;

    my $snp_fh = Genome::Sys->open_file_for_reading($self->snp_file);
    unless($snp_fh) {
        $self->error_message("Failed to open input filehandle for: " .  $self->snp_file );
        return;
    }

    my $output_fh = Genome::Sys->open_file_for_writing($self->output_file);
    unless($output_fh) {
        $self->error_message("Failed to open output filehandle for: " .  $self->output_file );
        return;
    }

    #print output header
    print $output_fh "chromosome\tstart\tend\tdbSNP-129\n";

    # TODO: let the caller do this from any model   
    # Due to the new import-ref-seq implementaion, NCBI-human
    # model/build got changed, *.dat will not exist anymore. So use
    # hard-coded path fro now. But this module is not needed anyway.

    my $model = Genome::Model->get(name => "dbSNP-human-build36-93636924");
    unless ($model) {
       die "failed to find build 36 Hs?";
    }

    my $cur_chr = 0;
    my $dbsnp_fh;
    my $dbsnp_row;
    my ($variant_position, $variant_allele, $variant_class);

    my $path;
    #assuming we are reasonably sorted


    
    while (my $line = $snp_fh->getline) {
        chomp $line;
        my ($chr,$pos,) = split /\s+/, $line; 
        
        if($chr ne $cur_chr) {
            # switch to a new chromosome, and open its file
            my $alter_chr = $chr;
            ($alter_chr) = $chr =~ /^chr(\S+)$/ if $chr =~ /^chr/;
            #$path = $build->data_directory . "/annotation/dbsnp-variations/$alter_chr.dat";
            $path = $model->data_directory."/ImportedVariations/$alter_chr.dat";
            $dbsnp_fh = IO::File->new($path);
            
            ###jpeck added if/then after per chromosome to whole genome pipeline conversion in April 2009
            ###confirmed approach with D. Larson 
            if ( -s $path )  {
   
                #original code 
                $dbsnp_row = $dbsnp_fh->getline;
                ($variant_position,$variant_class,$variant_allele) = split(/\s+/,$dbsnp_row);
                $cur_chr = $chr;
                print STDERR "Annotating $cur_chr\n";

            } else {
                print "*** Path $path does not exist(1).  Skipping $cur_chr \n";
            }
        }

        # advance to the dbsnp data for this position 
        while($variant_position < $pos) {

            ###jpeck added if/then. See note above.
            if ( -s $path )  {
                $dbsnp_row = $dbsnp_fh->getline;
            } else {
                print "*** Path $path does not exist(2).\n";
                $dbsnp_row = undef;
            }
 
            last if not defined $dbsnp_row;
            ($variant_position,$variant_class,$variant_allele) = split(/\s+/,$dbsnp_row);

        };
        
        # if we're at the end of the dbsnp data, move onto the next snp comparison
        next if not defined $dbsnp_row;
        
        # there may be multiple rows of dbsnp data for this position
        # ...just go until we find the first row which represents a snp, not an indel
        while($variant_position == $pos) {   
            if($pos == $variant_position && $variant_class eq 'snp') {
                printf $output_fh "%s\t%d\t%d\t1\n",$chr,$pos,$pos;
                last;
            }
            else {
                ###jpeck, added if/then
                if ( -s $path )  {
                     $dbsnp_row = $dbsnp_fh->getline;
                } else {
                    print STDERR "*** Path is undefined(3): $path \n";
                    $dbsnp_row = undef;
                } 

                last if not defined $dbsnp_row;
                ($variant_position,$variant_class,$variant_allele) = split(/\s+/,$dbsnp_row);
            }
        }
    }

    if (defined($dbsnp_fh)) {
	$dbsnp_fh->close;
    }
   
    if (defined($snp_fh)) { 
    	$snp_fh->close; 
    }

    if (defined($output_fh)) { 
    	$output_fh->close;
    }

    return 1;
}

1;

sub help_detail {
    return "This module takes a snp list and creates a file of its intersections with dbSNP-129";
}

sub help_brief {
    return "Create a dbSNP/Watson/Venter file";
}

