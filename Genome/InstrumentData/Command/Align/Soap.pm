package Genome::InstrumentData::Command::Align::Soap;

use strict;
use warnings;

use Genome;

class Genome::InstrumentData::Command::Align::Soap {
    is => ['Genome::InstrumentData::Command::Align'],
    has_constant => [
        aligner_name => { value => 'soap' },
    ],
    has => [
        version => {is=>'String', default_value=>Genome::Model::Tools::Soap->default_soap_version}
    ],
    doc => "align instrument data using Bowtie's novoalign tool (see http://bowtie-bio.sourceforge.net)",
};

sub help_synopsis {
# TODO: Make these actual examples of valid run arguments.
return <<EOS
genome instrument-data align soap

genome instrument-data align soap

genome instrument-data align soap

genome instrument-data align soap
EOS
}

sub help_detail {
return <<EOS
Launch the SOAP aligner in a standard way and produce results ready for the genome modeling pipeline.

See http://soap.genomics.org.cn/soapaligner.html for more information.
EOS
}


1;

