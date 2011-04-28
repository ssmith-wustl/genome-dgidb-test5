package Genome::Model::Tools::Music;
use strict;
use warnings;
use Genome;
our $VERSION = '0.01';

class Genome::Model::Tools::Music {
    is => ['Command::Tree'],
    doc => 'Mutational Significance in Cancer (Cancer Mutation Analysis)'
};

sub _doc_manual_body {
    return <<EOS
The MuSiC suite is a set of tools aimed at discovering the significance of somatic mutations found within a given cohort of cancer samples, and with respect to a variety of external data sources. The standard inputs required are 1) mapped reads in BAM format 2) predicted or validated SNVs or indels in mutation annotation format (MAF) 3) a list of regions of interest (typically the boundaries of coding exons) 4) any relevant numeric or categorical clinical data. The formats for inputs 3) and 4) are:

3) Regions of Interest File:
- Do not use headers
- 4 columns, which are [chromosome  start-position(1-based)  stop-position(1-based)  gene_name]

4) Clinical Data Files:
- Headers are required
- At least 1 sample_id column and 1 attribute column, with the format being [sample_id  clinical_data_attribute  clinical_data_attribute  ...]
- The sample_id must match the sample_id listed in the MAF under "Tumor_Sample_Barcode" for relating the mutations of this sample.
- The header for each clinical_data_attribute will appear in the output file to denote relationships with the mutation data from the MAF.

Descriptions for the usage of each tool (each sub-command) can be found separately. 

The B<play> command runs all of the sub-commands serially on a selected input set.

EOS
}

sub _doc_copyright_years {
    (2007,2011);
}

sub _doc_license {
    my $self = shift;
    my (@y) = $self->_doc_copyright_years;  
    return <<EOS
Copyright (C) $y[0]-$y[1] Washington University in St. Louis.

It is released under the Lesser GNU Public License (LGPL) version 3.  See the 
associated LICENSE file in this distribution.
EOS
}

sub _doc_authors {
    return (
        <<EOS,
This software is developed by the analysis and engineering teams at 
The Genome Institute at Washington University School of Medicine in St. Louis,
with funding from the National Human Genome Research Institute.  Richard K. Wilson, P.I.

The primary authors of the MuSiC suite are:
EOS
        'Nathan D. Dees, Ph.D.',
        'Cyriac Kandoth, Ph.D.',
        'Dan Koboldt, M.S.',
        'William Schierding, M.S.',
        'Michael Wendl, Ph.D.',
        'Qunyuan Zhang, Ph.D.',
        'Thomas B. Mooney, M.S.',
    );
}


sub _doc_bugs {   
    return <<EOS;
For defects with any software in the genome namespace, contact
 genome-dev ~at~ genome.wustl.edu.
EOS
}

sub _doc_credits {
    return (
        <<EOS,
The MuSiC suite uses tabix, by Heng Li.  See http://samtools.sourceforge.net/tabix.shtml.

MuSiC depends on copies of data from the following databases, packaged in a form useable for quick analysis:
EOS
        "* KEGG - http://www.genome.jp/kegg/",
        "* COSMIC - http://www.sanger.ac.uk/genetics/CGP/cosmic/",
        "* OMIM - http://www.ncbi.nlm.nih.gov/omim",
        "* Pfam - http://pfam.sanger.ac.uk/",
        "* SMART - http://smart.embl-heidelberg.de/",
        "* SUPERFAMILY - http://supfam.cs.bris.ac.uk/SUPERFAMILY/",
        "* PatternScan - http://www.expasy.ch/prosite/",
    );
}

sub _doc_see_also {
    'B<genome>(1)',
}

1;

