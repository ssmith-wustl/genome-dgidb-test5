
use strict;
use warnings;

use Genome;

package Genome::Model::Tools::Galaxy::Tail;

class Genome::Model::Tools::Galaxy::Tail {
    is => ['Command'],
    attributes_have => [
        file_format => {
            is => 'String',
            is_optional => 1
        },
        same_as => {
            is => 'String',
            is_optional => 1
        }
    ],
    has_input => [
        input_file => {
            is => 'file_path',
            file_format => 'txt'
        },
        output_file => {
            is => 'file_path',
            same_as => 'input_file',
            is_output => 1
        },
        line_count => {
            is => 'integer',
            len => 5,
            default_value => 10 
        }
    ]
};

sub sub_command_sort_position { 10 }

sub help_brief {
    "lines from a Query";
}

sub help_synopsis {
    return <<"EOS"
EOS
}

sub help_detail {
    return <<"EOS"

**What it does**

This tool outputs specified number of lines from the **end** of a dataset

-----

**Example**

- Input File::

    chr7    57134   57154   D17003_CTCF_R7  356     -
    chr7    57247   57267   D17003_CTCF_R4  207     +
    chr7    57314   57334   D17003_CTCF_R5  269     +
    chr7    57341   57361   D17003_CTCF_R7  375     +
    chr7    57457   57477   D17003_CTCF_R3  188     +

- Show last two lines of above file. The result is::

    chr7    57341   57361   D17003_CTCF_R7  375     +
    chr7    57457   57477   D17003_CTCF_R3  188     +

EOS
}

sub execute {
    my $self = shift;
   
    my $input_file = $self->input_file;
    my $output_file = $self->output_file; 
    my $line_count = $self->line_count;

    open (OUT, ">$output_file") or die "Cannot create $output_file:$!\n";
    open (TAIL, "tail -n $line_count $input_file|") or die "Cannot run tail:$!\n";
    while (<TAIL>) {
        print OUT;
    }
    close OUT;
    close TAIL;

}

1;
