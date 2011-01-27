package Genome::ProcessingProfile::GenotypeMicroarray;

use Genome;

class Genome::ProcessingProfile::GenotypeMicroarray {
    is => 'Genome::ProcessingProfile',
    has_param => [
        input_format => {
            doc => 'file format, defaults to "wugc", which is currently the only format supported',
            valid_values => ['wugc'],
            default_value => 'wugc',
        },
        instrument_type => {
            doc => 'the type of microarray instrument',
            valid_values => [qw/ affymetrix illumina infinium unknown /],
        },
    ],
};

sub _execute_build {
    my ($self, $build) = @_;
    
    $self->status_message('Execute genotype microarray build '.$build->__display_name__);

    my $instrument_data = $build->instrument_data;
    if ( not $instrument_data ) { # ok for now
        $self->status_message('OK: No instrument data for genotype microarray build '.$build->__display_name__);
        return 1;
    }

    my $subject_name = $reference_sequence_build->subject_name;
    my $version = $reference_sequence_build->version;
    $self->status_message("Getting genotype microarray file for subject ($subject_name) and version ($version) in instrument data ".$instrument_data->__display_name__);
    my $genotype_file = $instrument_data->genotype_microarray_file_for_subject_and_version($subject_name, $version);
    if ( not -s $genotype_file ) { 
        $self->error_message('No genotype microarray file available. This file is expected if genotype models have instrument data'); 
        return;
    }
    $self->status_message('Genotype microarray file: '.$genotype_file);

    my $snp_array_file = $build->formatted_genotype_file_path;
    $self->status_message("Create snp array (gold) file: ".$snp_array_file);
    my $gold_snp = Genome::Model::Tools::Array::CreateGoldSnpFromGenotypes->execute(    
        genotype_file1 => $genotype_file,
        genotype_file2 => $genotype_file,
        output_file => $snp_array_file,
    );
    if ( not $gold_snp or $gold_snp->result ) {
        $self->error_message("SNP Array Genotype creation failed");
        die $self->error_message;
    }
    if ( not -s $snp_array_file ) {
        $self->error_message();
        return;
    }
    $self->status_message("Create snp array (gold) file...OK");

    $self->status_message('Execute genotype microarray build...OK');

    return 1;
}

1;

