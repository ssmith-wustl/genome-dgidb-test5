package Genome::Model::Command::Annotate::AmlReportChunker;

use strict;
use warnings;

use above "Genome";                

class Genome::Model::Command::Annotate::AmlReportChunker {
    is => 'Command',                       
    has => [   
    #removed this option, siunce it is overridden below
    #dev => { type => 'String', doc => "?", is_optional => 0 },
    list1 => { type => 'String', doc => "?", is_optional => 0 },
    create_input => { type => 'Boolean', doc => "?", is_optional => 1 },
    output => { type => 'String', doc => "?", is_optional => 0 },
    ], 
};

sub sub_command_sort_position { 12 }

sub help_brief {
    "WRITE A ONE-LINE DESCRIPTION HERE"                 
}

sub help_synopsis {                         # replace the text below with real examples <---
    return <<EOS
genome-model example1 --foo=hello
genome-model example1 --foo=goodbye --bar
genome-model example1 --foo=hello barearg1 barearg2 barearg3
EOS
}

sub help_detail {                           # this is what the user will see with the longer version of help. <---
    return <<EOS 
This is a dummy command.  Copy, paste and modify the module! 
CHANGE THIS BLOCK OF TEXT IN THE MODULE TO CHANGE THE HELP OUTPUT.
EOS
}

#sub create {                               # rarely implemented.  Initialize things before execute.  Delete unless you use it. <---
#    my $class = shift;
#    my %params = @_;
#    my $self = $class->SUPER::create(%params);
#    # ..do initialization here
#    return $self;
#}

#sub validate_params {                      # pre-execute checking.  Not requiried.  Delete unless you use it. <---
#    my $self = shift;
#    return unless $self->SUPER::validate_params(@_);
#    # ..do real checks here
#    return 1;
#}

sub execute {   
    my $self = shift;

    #!/gsc/bin/perl

    use strict;
    use warnings;

    use Getopt::Long;
    use Carp;
    use DBI;
    use LSF::Job;


    # removed GetOptions, added getting options from 'self'
    # added option flag 'create_input' to replace checking for the
    # ARGV[0]
    my %options = ( 
        #'dev'         => $self->dev,
        'list1'		=>$self->list1,
        'out' =>$self->output,
        'create_input' =>$self->create_input,
    );
    my $quality=">=30";
=pod
    GetOptions( 

        'devel=s'       => \$options{'dev'},
        'list1=s'       => \$options{'list1'},
        'output=s'       => \$options{'out'},
    );
    $options{'list1'}=~tr/-/ / if(defined $options{'list1'});
=cut

    # overridden below
    #unless(defined($options{'dev'}) ) {
    #    croak "usage $0 --dev <database sample_data/sd_test..>";
    #}


    my($Srv) = 'mysql2';
    my($Uid) = "mgg_admin";
    my($Pwd) = q{c@nc3r};
    my($database) = "sample_data";
    #my($database) = $options{'dev'};

    my($X);
# $X cannot have 'my($X)' or else it will close every time.
    ($X = DBI->connect("DBI:mysql:$database:$Srv", $Uid, $Pwd))  or (die "fail to connect to datase \n");





    my $sql_3 = <<EOS
select  chr.chromosome,rgg1.start,rgg1.end,
rgg1.allele1,rgg1.allele2,rgg1.allele1_type,rgg1.allele2_type,rgg1.num_reads1,rgg1.num_reads2
from  read_group_genotype rgg1 
join chromosome chr on chr.chrom_id=rgg1.chrom_id
where rgg1.read_group_id=(
select rg1.read_group_id from read_group rg1
where rg1.pp_id=( select pp1.pp_id from process_profile pp1
where pp1.concatenated_string_id=?)) limit 1000
EOS
    ;
    # added limit 1000 for testing

    print $options{'list1'},":query database\n";
    if($options{create_input}) {
        open(OUT,">$options{'out'}.dump") or die "can't open $options{'out'}.dump $!";
        my $sth;
        # commentted out the rm below, replacing with unlnking out file
        #`rm -rf ~xshi/dump/$options{'out'}.dump`;
        unlink $options{out} if -e $options{out};

        ($sth) = $X->prepare($sql_3) ;

        $sth->execute($options{'list1'}) ;
        while(my @re=$sth->fetchrow_array){
            print OUT join("\t",@re),"\n";
#print @re,"\n";
        }
        close(OUT);
        $sth->finish;
        print "query finished\n";
    }
    $X->disconnect;

    # ending here, only getting the first 1000 for testing
    return 1;
    
    `split $options{'out'}.dump $options{'out'}.dump_ -l 300000`;

#my @files=`ls $options{'out'}.dump_*`;
    my @files = <$options{'out'}.dump_[a-z][a-z]>;

    foreach my $file (@files){
        print "excute file $file\n";
        my $job = LSF::Job->submit(-oo => $file.'.bsub' ,"perl /gscuser/xshi/work/AML_SNP/aml_snp_report_paralle_module.pl --dev $options{'dev'} --file $file  ");
    }

    return 1;  
}

1;

