package Genome::Model::Command::Annotate::RemoveSnpsSubmittedForValidation;  

use strict;
use warnings;

use above "Genome";                         

class Genome::Model::Command::Annotate::RemoveSnpsSubmittedForValidation 
{
    is => 'Command',                       
    has =>
    [                                
    input_file => 
    {
        type => 'String',
        doc => "Input file", 
        is_optional => 0,
    },
    output_file => 
    {
        type => 'String',
        doc => "Output file", 
        is_optional => 1 
    },
    #   variant_validation  => { type => 'String', doc => "The variant validation .csv file", default => '/gscuser/xshi/work/AML_SNP/VALIDATION/Ley_Siteman_AML_variant_validation.10mar2008a.csv' }, 
    ], 
};

require Cwd;
require IO::File;

sub help_brief {
}

sub help_synopsis { 
    return <<EOS
EOS
}

sub help_detail {  
    return <<EOS 
EOS
}

sub execute {     

    my $self = shift;

    my $in = Cwd::abs_path( $self->input_file );
    my $out = Cwd::abs_path( $self->output_file  ) || "$in.out";
    unlink $out if -e $out;

    # FIXME get list exclusion info from DB!
    my $list = '/tmp/list';
    unlink $list if -e $list;
    `cat Ley_Siteman_AML_variant_validation.10mar2008a.csv | awk '{FS="\t";if(\$42=="G"||\$42=="WT"||\$42=="S"||\$42=="LOH"||\$42=="O") print \$2","\$4","\$5","\$6;}' > list`;
    `grep -v -f list $in > $out`;

    unlink $list;

    return 1;

    # FIXME unshell-ify!
    ####################

    my $input_fh = IO::File->new($self->input);
    my $variant_fh = IO::File->new($self->variant_validation);

#cat Ley_Siteman_AML_variant_validation.10mar2008a.csv | 
#awk '{FS="\t";

    my $matches;
    while (my $line = $variant_fh->getline) {
        my @columns = split('\t', $line);

        if($columns[41]eq"G"||$columns[41]eq"WT"||$columns[41]eq"S"||$columns[41]eq"LOH"||$columns[41]eq"O") {
            $matches .= $columns[1].",".$columns[3].",".$columns[4].",".$columns[5]."\n";	# > list
        }
    }

    system("grep -v -F '$matches' ".$self->input);

    return 0;
}

1;

