package Genome::Model::Tools::Snp::C45;

use strict;
use warnings;

use above "Genome";
use Command;
use IO::File;

class Genome::Model::Tools::Snp::C45 {
    is => 'Command',
    has => [
    good_snps_file => 
    { 
        type => 'String',
        is_optional => 0,
        doc => "input file of known real snps with
        lots of data about them in columns",
    },
    bad_snps_file =>
    {
        type => 'String',
        is_optional => 0,
        doc => "input file of known false snps with
        lots of data about them in columns",
    },
    name_file =>
    {
        type => 'String',
        is_optional => 1,
        doc => "config file detailing name and range 
        of columns in the two snp files for C4.5",
    },
    training_set_size =>
    {
        type => 'Integer',
        is_optional => 1,
        doc => "Size of training set. default=200.
                Specify 'all' to use entire input.",
        default => '200'
    },        
    data_file =>
    {
        type => 'String',
        is_optional => 1,
        doc => "file of data which C4.5 will use to 
        attempt to construct good rules. If not specified
        a default subset will be created at runtime",
    },
    test_file =>
    {  
        type => 'String',
        is_optional =>1,
        doc => "file of data which C4.5 will use to
        test out the rules it decides on. if not specified,
        good/bad concat will be used",
    }       
    ]
};


sub execute {
    my $self=shift;
    unless(-f $self->good_snps_file) {
        $self->error_message("Good snps file is not a file: " . $self->good_snps_file);
        return;
    }
    unless(-f $self->bad_snps_file) {
        $self->error_message("bad snps file is not a file: " . $self->bad_snps_file);
        return;
    }
    #unless(-f $self->name_file) {
    #    $self->error_message("bad snps file is not a file: " . $self->name_file);
    #     return;
    #}
    #unless($self->test_file && -f $self->test_file) {
    #   $self->error_message("bad snps file is not a file: " . $self->test_file);
    #return;
    #}
    # unless($self->data_file && -f $self->data_file) {
    #    $self->error_message("bad snps file is not a file: " . $self->data_file);
    # return;
    # }
      my $good_fh=IO::File->new($self->good_snps_file);
    my $bad_fh=IO::File->new($self->bad_snps_file);
    unless($bad_fh && $good_fh) {
        $self->error_message("Failed to open filehandles for: " .  $self->good_snps_file . " and/or " . $self->bad_snps_file);
        return;
    }


    #lots of processing goes here... to both bad and good files
    #independify various columsn, add WT/G to end of each line
    #they should probably be written either to two new files or just dumped right into test and data files. 



    #if we didn't specify a data file. probably the normal case.
    unless($self->data_file) {
        $self->data_file("/tmp/C45.data");
        my $data_file_handle=IO::File->new(">" . $self->data_file);
        ###use some procedure to fill this with a random subset of shit(stuff).
    } 
    unless($self->test_file) {
        $self->test_file("/tmp/C45.test");
        my $data_file_handle=IO::File->new(">" . $self->test_file);
        #concatenate both files and shove them in here.
    } 
    ###Run C4.5 here



}
1;

sub help_detail {
    "This module is intended to be a front end for running C4.5 to generate decision trees"
}

####PSEUDOCODE#####
#INPUT: LIST OF GOOD SNPS with experimental appended
#INPUT: LIST OF BAD SNPS with experimental appended



####FIRST THING TO DO
####MODIFY COLUMNS TO MAKE ANY RELATED COLUMNS INDEPENDENT
####APPEND STATUS OF ,G to GOOD SNPS file. 
### APPEND STATUS OF ,WT TO BAD SNPS file.

##LIST ALTERATION/PROCESSING DONE

###CONCATENATE LISTS INTO NEW FILE

##GENERATE ANCILLARY CONFIG FILES FOR C4.5
##.NAMES - names of columns and how they vary. "continous"  "discrete: good, bad"
##.DATA - training set
##.TEST - test set
