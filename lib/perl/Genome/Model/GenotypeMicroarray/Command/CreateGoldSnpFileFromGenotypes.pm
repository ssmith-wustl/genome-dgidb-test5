package Genome::Model::GenotypeMicroarray::Command::CreateGoldSnpFileFromGenotypes;

use strict;
use warnings;
use Genome;

class Genome::Model::GenotypeMicroarray::Command::CreateGoldSnpFileFromGenotypes {
    is => 'Command',
    has => [
        output_file => {
            is => 'FilePath',
            doc => 'Gold snp output file',
        },
    ],
    has_optional => [
        genotype_file_1 => {
            is => 'FilePath',
            doc => 'input file of genotypes from one platform',
        },
        genotype_file_2 => {
            is => 'FilePath',
            doc => 'input file of genotypes from additional platform',
        },
        genotype_build_id_1 => {
            is => 'Number',
            doc => 'Build id of first genotype microarray build',
        },
        genotype_build_1 => {
            is => 'Genome::Model::Build::GenotypeMicroarray',
            doc => 'First genotype microarray build',
        },
        genotype_build_id_2 => {
            is => 'Number',
            doc => 'Build id of second genotype microarray build',
        },
        genotype_build_2 => {
            is => 'Genome::Model::Build::GenotypeMicroarray',
            doc => 'Second genotype microarray build',
        },
        reference_sequence_build_id => {
            is => 'Number',
            doc => 'Build id of reference sequence build',
        },
        reference_sequence_build => {
            is => 'Genome::Model::Build::ImportedReferenceSequence',
            id_by => 'reference_sequence_build_id',
            doc => 'Reference sequence build',
        },
    ],
};

sub help_brief { return 'Creates a gold snp file from two genotype files' };
sub help_synopsis { return help_brief() };
sub help_detail { return help_brief() };

sub execute {
    my $self = shift;

    # Make sure we got a reference
    unless ($self->reference_sequence_build) {
        Carp::confess 'Could not resolve reference sequence build!';
    }

    $self->resolve_genotype_files;

    # Check and open filehandles    
    my $genotype_fh1 = IO::File->new($self->genotype_file_1);
    unless($genotype_fh1) {
        Carp::confess "Failed to open filehandle for: " . $self->genotype_file_1;
        return;
    }
    my $genotype_fh2 = IO::File->new($self->genotype_file_2);
    unless($genotype_fh2) {
        Carp::confess "Failed to open filehandle for: " . $self->genotype_file_2;
        return;
    }
    my $output_fh = IO::File->new($self->output_file,"w");
    unless($output_fh) {
        Carp::confess "Failed to open filehandle for: " . $self->output_file;
        return;
    }

    my ($chr2, $pos2, $genotype2) = (1,1,q{}); #expecting 

    while(my $line1 = $genotype_fh1->getline) {
        chomp $line1;

        my ($chr1, $pos1, $genotype1) = split /\s+/, $line1;

        my $line2;
        while((($pos1 > $pos2 && $chr1 eq $chr2) || ($pos1 < $pos2 && $chr1 ne $chr2))  && ($line2 = $genotype_fh2->getline)) {
            ($chr2, $pos2, $genotype2) = split /\s+/, $line2;
        }

        if($chr2 eq $chr1 && $pos1 == $pos2) {
            #intersecting position
            #check genotypes
            my @alleles = split //, uc($genotype1);
            my $ref = $self->reference_sequence_build->sequence($chr1, $pos1, $pos1);

            if($genotype1 ne '--' && $genotype1 =~ /[ACTGN]/ && $genotype2 =~ /[ACTGN]/ && ($genotype1 eq $genotype2 || $genotype1 eq reverse($genotype2))) {

                #print genotypes with call
                my $type1 = ($alleles[0] eq $ref) ? 'ref' : 'SNP';
                my $type2 = ($alleles[1] eq $ref) ? 'ref' : 'SNP';
                print $output_fh "$chr1\t$pos1\t$pos1\t$alleles[0]\t$alleles[1]\t$type1\t$type2\t$type1\t$type2\n";
            }
        }

    }

    return 1;
}

sub resolve_genotype_files {
    my $self = shift;
    if (defined $self->genotype_file_1 or $self->genotype_build_1) {
        unless (defined $self->genotype_file_1 and -f $self->genotype_file_1) {
            my $file1 = $self->genotype_build_1->genotype_file_path;
            Carp::confess 'Could not resolve genotype file from build ' . $self->genotype_build_id_1 unless -f $file1;
            $self->genotype_file_1($file1);
        }
    }
    else {
        Carp::confess 'Need to provide either a build or a file path for first bit of genotype data';
    }

    if (defined $self->genotype_file_2 or $self->genotype_build_2) {
        unless (defined $self->genotype_file_2 and -f $self->genotype_file_2) {
            my $file2 = $self->genotype_build_2->genotype_file_path;
            Carp::confess 'Could not resolve genotype file from build ' . $self->genotype_build_id_2 unless -f $file2;
            $self->genotype_file_2($file2);
        }
    }
    else {
        Carp::confess 'Need to provide either a build or a file path for second bit of genotype data';
    }

    return 1;
}

1;

