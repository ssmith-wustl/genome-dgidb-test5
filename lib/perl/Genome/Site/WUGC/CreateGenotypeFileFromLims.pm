package Genome::Site::WUGC::CreateGenotypeFileFromLims;

use strict;
use warnings;

use GSCApp;

if ( not App::Init->initialized ) {
    App::DB->db_access_level('rw');
    App->init;
}

use Genome;

use Data::Dumper 'Dumper';

class Genome::Site::WUGC::CreateGenotypeFileFromLims {  
    is => 'Command',
    has => [
        db_snp_version => {
            is => 'Integer',
            valid_values => [qw/ 130 132 /],
            doc => 'DB SNP build version',
        },
        genotype_id => {
            is => 'Integer',
            doc => 'The seq id of the genotyping object',
        },
        genotype_file => {
            is => 'Text',
            doc => 'Output file for genotypes',
        },
    ],
};

sub execute {
    my $self = shift;

    # dbSNP
    my $db_snp = GSC::SNP::DB::Info->get(snp_db_build => $self->db_snp_version);
    if ( not $db_snp ) {
        $self->error_message('Could not get dbsnp build for version: '.$self->db_snp_version);
        return;
    }
    $self->status_message('dbSNP version: '.$db_snp->snp_db_build);
    $self->status_message('Reference version: '.$db_snp->genome_build);

    # Reference type
    my %types_for_reference = (
        36.3 => 'reference', # dbsnp 130
        37.1 => 'GRCh37', # dbsnp 132
    );
    my $type = $types_for_reference{ $db_snp->genome_build };
    if ( not $type ) {
        $self->error_message('No type for reference: '.$db_snp->genome_build);
        return;
    }
    $self->status_message('Reference type: '.$type);
    
    # Data adapter params
    my %params = ( 
        genome_build => $db_snp->genome_build,
        snp_db_build => $db_snp->snp_db_build,
        type => $type,
    );

    # Genotype
    my $genotype;
    for my $genotype_class (qw/ GSC::Genotyping::Internal::Illumina GSC::Genotyping::External /) {
        $genotype = $genotype_class->get($self->genotype_id);
        last if $genotype;
    }
    if ( not $genotype ) {
        $self->error_message('Could not get genotype for id: '.$self->genotype_id);
        return;
    }
    my $genotype_class = ref $genotype;
    $self->status_message($genotype_class.' '.$genotype->id);
    if ( $genotype_class eq 'GSC::Genotyping::Internal::Illumina' ) {
        my $filter = DataAdapter::Result::Filter::Nathan->new();
        if ( not $filter ) {
            $self->error_message('Could not get "Nathan" filter');
            return;
        }
        $self->status_message('Using "Nathan" filter');
        $params{filter} = $filter;
    }
    
    # Dat adapter
    my $data_adapter = $genotype->get_genotype_data_adapter(%params);
    if ( not $data_adapter ) {
        $self->error_message('Could not get data adapter');
        return;
    }
    $self->status_message('Got data adapter');

    # Files
    my $genotype_file = $self->genotype_file;
    $self->status_message('Genotype file: '.$genotype_file);
    unlink $genotype_file if -e $genotype_file;
    my $unsorted_genotype_file .= $genotype_file.'.unsorted';
    $self->status_message('Unsorted genotype file: '.$unsorted_genotype_file);
    unlink $unsorted_genotype_file if -e $unsorted_genotype_file;
    my $fh = IO::File->new($unsorted_genotype_file, 'w') or die "Could not open file ($unsorted_genotype_file)";
    if ( not $fh ) {
        $self->error_message("Could not opne file ($genotype_file): $!");
        return;
    }
    $fh->autoflush(1);

    # Dump
    $self->status_message("Generate unsorted SNPs");
    my $unsorted_genotype_count = 0;
    while ( my $result = $data_adapter->next_result ) {
        my @attrs = ( qw/ chromosome position alleles / );
        for my $attr ( @attrs ) {
            if ( not defined $result->$attr ) {
                $fh->close;
                unlink $unsorted_genotype_file;
                $self->error_message("Did not find $attr in data adapter result");
                return;
            }
        }
        $fh->print( join ("\t", map { $result->$_ } ( @attrs ) )."\n" );
        $unsorted_genotype_count++;
    }
    $fh->close;
    $self->status_message("Unsorted genotype count: $unsorted_genotype_count");
    $self->status_message("Generate unsorted SNPs...OK");

    # Sort
    $self->status_message("Sort SNPs");
    my $sort = Genome::Model::Tools::Snp::Sort->create(
        snp_file => $unsorted_genotype_file,
        output_file => $genotype_file,
    );
    if ( not $sort ) {
        unlink $unsorted_genotype_file;
        $self->error_message('Failed to create sort command');
        return;
    }
    $sort->dump_status_messages(1);
    if ( not $sort->execute ) {
        unlink $genotype_file;
        unlink $unsorted_genotype_file;
        $self->error_message('Failed to execute sort command');
        return;
    }
    unlink $unsorted_genotype_file;
    $self->status_message("Sort SNPs...OK");

    # Validate file
    $self->status_message('Validate sorted genotype file');
    if ( not -s $genotype_file ) {
        $self->error_message("Snp sort command succeeded, but sorted file ($genotype_file) does not exist");
        return;
    }
    my $genotype_count = `wc -l $genotype_file`;
    $self->status_message("Sorted genotype count: $genotype_count");
    $self->status_message('Validate sorted genotype file...OK');

    return 1;
}

1;

