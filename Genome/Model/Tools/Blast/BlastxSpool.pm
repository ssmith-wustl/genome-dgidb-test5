
package Workflow::Command::Example::BlastxSpool;

# This is going to be:
# genome workflow example fasta-to-spool
# workflow example fasta-to-spool --fasta inputfile
class Workflow::Command::Example::BlastxSpool {
    is => ['Workflow::Operation::Command'],
    workflow => sub { 
        my $file = __FILE__;
        $file =~ s/\.pm$/.xml/;
        Workflow::Operation->create_from_xml($file); 
    }
};

1;
