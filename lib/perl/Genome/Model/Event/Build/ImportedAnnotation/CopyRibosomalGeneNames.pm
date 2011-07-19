package Genome::Model::Event::Build::ImportedAnnotation::CopyRibosomalGeneNames;

use strict;
use warnings;
use Genome;

class Genome::Model::Event::Build::ImportedAnnotation::CopyRibosomalGeneNames {
    is => 'Command::V2',
    has => [
        output_file => {
            is => 'FilePath',
            doc => 'Path to output the RibosomalGeneNames to',
        }
    ],
};

sub execute {
    my $self = shift;
    my $output_fh = Genome::Sys->open_file_for_writing($self->output_file);
    $output_fh->print($self->get_ribosomal_gene_names);
    $output_fh->close;
    return 1;
}

sub get_ribosomal_gene_names { 
    my $self = shift;
    my $ribosomal_gene_names = <<EOS;
RN5-8S1	ENSG00000241335
RN5-8S1	ENSG00000242716
RN18S1	ENSG00000225840
RN28S1	ENSG00000226958
MRPL12	ENSG00000183048
MRPL19	ENSG00000115364
MRPL3	ENSG00000114686
MRPL39	ENSG00000154719
PSMC4	ENSG00000013275
RN5S1	ENSG00000199352
RN5S10	ENSG00000199910
RN5S11	ENSG00000199334
RN5S12	ENSG00000199270
RN5S13	ENSG00000202526
RN5S14	ENSG00000201355
RN5S15	ENSG00000201925
RN5S16	ENSG00000202257
RN5S17	ENSG00000199270
RN5S17	ENSG00000199334
RN5S17	ENSG00000199337
RN5S17	ENSG00000199352
RN5S17	ENSG00000199396
RN5S17	ENSG00000199910
RN5S17	ENSG00000200343
RN5S17	ENSG00000200370
RN5S17	ENSG00000200381
RN5S17	ENSG00000200624
RN5S17	ENSG00000201355
RN5S17	ENSG00000201588
RN5S17	ENSG00000201925
RN5S17	ENSG00000202257
RN5S17	ENSG00000202521
RN5S17	ENSG00000202526
RN5S2	ENSG00000201588
RN5S3	ENSG00000199337
RN5S4	ENSG00000200381
RN5S5	ENSG00000199396
RN5S6	ENSG00000200624
RN5S7	ENSG00000202521
RN5S8	ENSG00000200343
RN5S9	ENSG00000201321
RPL10	ENSG00000147403
RPL10A	ENSG00000198755
RPL10L	ENSG00000165496
RPL11	ENSG00000142676
RPL12	ENSG00000197958
RPL13	ENSG00000167526
RPL13A	ENSG00000142541
RPL14	ENSG00000188846
RPL15	ENSG00000174748
RPL17	ENSG00000215472
RPL18	ENSG00000063177
RPL18A	ENSG00000105640
RPL19	ENSG00000108298
RPL21	ENSG00000122026
RPL22	ENSG00000116251
RPL22L1	ENSG00000163584
RPL23	ENSG00000125691
RPL23A	ENSG00000198242
RPL24	ENSG00000114391
RPL26	ENSG00000161970
RPL26L1	ENSG00000037241
RPL27	ENSG00000131469
RPL27A	ENSG00000166441
RPL28	ENSG00000108107
RPL29	ENSG00000162244
RPL3	ENSG00000100316
RPL30	ENSG00000156482
RPL31	ENSG00000071082
RPL32	ENSG00000144713
RPL34	ENSG00000109475
RPL35	ENSG00000136942
RPL35A	ENSG00000182899
RPL36	ENSG00000130255
RPL36A	ENSG00000241343
RPL36AL	ENSG00000165502
RPL37	ENSG00000145592
RPL37A	ENSG00000197756
RPL38	ENSG00000237077
RPL39	ENSG00000198918
RPL39L	ENSG00000163923
RPL3L	ENSG00000140986
RPL4	ENSG00000174444
RPL41	ENSG00000229117
RPL5	ENSG00000122406
RPL6	ENSG00000223730
RPL7	ENSG00000147604
RPL7A	ENSG00000148303
RPL7L1	ENSG00000146223
RPL8	ENSG00000161016
RPL9	ENSG00000163682
RPLP0	ENSG00000089157
RPS10	ENSG00000124614
RPS11	ENSG00000243024
RPS12	ENSG00000112306
RPS13	ENSG00000110700
RPS14	ENSG00000164587
RPS15	ENSG00000115268
RPS15A	ENSG00000134419
RPS16	ENSG00000105193
RPS17	ENSG00000184779
RPS18	ENSG00000231500
RPS19	ENSG00000105372
RPS19BP1	ENSG00000187051
RPS2	ENSG00000140988
RPS20	ENSG00000008988
RPS21	ENSG00000171858
RPS23	ENSG00000186468
RPS24	ENSG00000138326
RPS25	ENSG00000118181
RPS26	ENSG00000197728
RPS27	ENSG00000177954
RPS27A	ENSG00000143947
RPS27L	ENSG00000185088
RPS28	ENSG00000233927
RPS29	ENSG00000213741
RPS3	ENSG00000149273
RPS3A	ENSG00000145425
RPS4X	ENSG00000198034
RPS4Y1	ENSG00000129824
RPS4Y2	ENSG00000157828
RPS5	ENSG00000083845
RPS6	ENSG00000137154
RPS6KB1	ENSG00000108443
RPS7	ENSG00000171863
RPS8	ENSG00000142937
RPS9	ENSG00000170889
RPSA	ENSG00000168028
RSL1D1	ENSG00000171490
RSL24D1	ENSG00000137876
UBA52	ENSG00000221983
EOS

return $ribosomal_gene_names; 

}

1;
