package Genome::Model::PolyphredPolyscan::CollateSampleGroupMutations;

use strict;
use warnings;

use MG::IO::Polyphred;
use MG::IO::Polyscan;
use File::Temp;

use GSC;
use GSCApp;
App::Init->_restore_isa_can_hooks();

class Genome::Model::PolyphredPolyscan::CollateSampleGroupMutations {
    is => ['Command'],
    has => [
        combined_input_columns => {
            is => 'ARRAY',
            value => [qw(
                chromosome 
                start 
                stop 
                sample_name
                pcr_product_name
                variation_type
                reference
                allele1 
                allele1_type 
                allele2 
                allele2_type 
                score
            )]
        }
    ],
    has_input => [
        parser_type => { 
            is => 'String', 
            doc => 'must by Polyphred or Polyscan' 
        },
        input_file => {
            is => 'String',
        },
        output_path => {
            is => 'String',
        }
    ],
    has_output => [
        output_file => { 
            is => 'String', 
            is_optional => 1, 
            doc => 'tab delimited output file' 
        }
    ],
};

sub create {
    my $self = shift->SUPER::create(@_);

    $self->combined_input_columns(
        [qw/ chromosome 
                start 
                stop 
                sample_name
                pcr_product_name
                variation_type
                reference
                allele1 
                allele1_type 
                allele2 
                allele2_type 
                score/]
    );

    return $self;
}

sub sub_command_sort_position { 10 }

sub help_brief {
}

sub help_synopsis {
    return <<"EOS"
Used by Genome::Model::PolyphredPolyscan
EOS
}

sub help_detail {
    return <<"EOS"
This should be filled in.
EOS
}

sub execute {
    my $self = shift;

    my @input_files;
    if (ref($self->input_file) eq 'ARRAY') {
        @input_files = @{ $self->input_file };
    } else {
        @input_files = ($self->input_file);
    }

    my $type = $self->parser_type;
    my ($fh, $output_filename) = File::Temp::tempfile('collate_csv_XXXXXXXX', DIR => $self->output_path, UNLINK => 0);
    $self->output_file($output_filename);

    # Create parsers for each file, append to running lists
    # TODO eliminate duplicates!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
    for my $file (@input_files) {
        #TODO make sure assembly project names are going to be kosher
        my ($assembly_project_name) = $file =~ /\/([^\.\/]+)\.poly(scan|phred)\.(low|high)$/;
        my $param = lc($type);
        my $module = "MG::IO::$type";
        my $parser = $module->new($param => $file,
                                  assembly_project_name => $assembly_project_name
                                 );
        my ($snps, $indels) = $parser->collate_sample_group_mutations;

        # Print all of the snps and indels to the combined input file
        for my $variant (@$snps, @$indels) {
            $fh->print( join("\t", map{$variant->{$_} } @{ $self->combined_input_columns } ) );
            $fh->print("\n");
        }
    }
    $fh->close;

    return 1;
}
 
1;
