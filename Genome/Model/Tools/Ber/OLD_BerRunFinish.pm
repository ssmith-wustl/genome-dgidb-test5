package Genome::Model::Tools::Ber::BerRunFinish;

use strict;
use warnings;

use Genome;
use Command;

use Carp;
use English;

use BAP::DB::Sequence;
use BAP::DB::SequenceSet;
use BAP::DB::CodingGene;
use Ace;
use Ace::Sequence;

use Data::Dumper;
use IO::File;
use IPC::Run qw/ run timeout /;
use Time::HiRes qw(sleep);
use DateTime;
use MIME::Lite;

use Cwd;

UR::Object::Type->define(
			 class_name => __PACKAGE__,
			 is         => 'Command',
			 has        => [
					'locus_tag'       => {
							      is  => 'String',
							      doc => "Locus tag for project, containing DFT/FNL postpended",
							     },
					'outdirpath'      => {
					                      is  => 'String',
							      doc => "output directory for the ber product naming software",
                                                             },
					'sqlitedatafile'  => {
                                                              is  => 'String',
							      doc => "Name of sqlite output .dat file",
							     },
					'sqliteoutfile'  => {
					                     is  => 'String',
							     doc => "Name of sqlite output .out file",
							     },
					'acedb_version'  => {
					                     is  => 'String',
							     doc => "Current acedb version",
					                    },
					'amgap_path'     => {
					                     is  => 'String',
							     doc => "Current path to AMGAP data",
					                    },
					'pipe_version'   => {
                                                             is  => 'String',
							     doc => "Current pipeline version running",
                                                            },
					'project_type'   => {
                                                             is  => 'String',
							     doc => "Current project type",
					                    },
					'org_dirname'    => {
					                     is  => 'String',
							     doc => "Current organism directory name",
					                    },
					'assembly_name'  => {
					                     is  => 'String',
							     doc => "Current assembly name",
					                    },
					'sequence_set_id'=> {
                                                             is  => 'String',
							     doc => "Current sequence set id",
					                    },
				       ]
			);

sub help_brief
  {
    "Tool for making the final BER ace file, write new parse script and parse into acedb via tace, gather stats from phase5 ace file and acedb, writes the rt file and mails when finished ";
  }

sub help_synopsis
  {
    return <<"EOS"
      Tool for making the final BER ace file, write new parse script and parse into acedb via tace, gather stats from phase5 ace file and acedb, writes the rt file and mails when finished.
EOS
  }

sub help_detail
  {
    return <<"EOS"
Tool for making the final BER ace file, write new parse script and parse into acedb via tace, gather stats from phase5 ace file and acedb, writes the rt file and mails when finished.
EOS
  }


#sub execute
 # {

 # }

sub execute
  {
      my $self          = shift;
      my $locus_tag     = $self->locus_tag;
      my $outdirpath    = $self->outdirpath;
      my $sqlitedata    = $self->sqlitedatafile;
      my $sqliteout     = $self->sqliteoutfile;
      my $acedb_ver     = $self->acedb_version;
      my $amgap_path    = $self->amgap_path;
      my $pipe_version  = $self->pipe_version;
      my $project_type  = $self->project_type;
      my $org_dirname   = $self->org_dirname;
      my $assembly_name = $self->assembly_name;
      my $ssid          = $self->sequence_set_id;

      my $cwd = getcwd();
      my $outdir = qq{/gscmnt/temp110/info/annotation/ktmp/BER_TEST/hmp/autoannotate/out};
      unless ($cwd eq $outdir) {
	  chdir($outdir) or die "Failed to change to '$outdir'...  from BerRunFinish.pm: $OS_ERROR\n\n";
      }

      my $sqlitedatafile = qq{$outdirpath/$sqlitedata};
      my $sqliteoutfile  = qq{$outdirpath/$sqliteout};
      unless ((-e $sqlitedatafile) and (! -z $sqlitedatafile )) {
	  croak qq{\n\n NO file,$sqlitedatafile, found for or empty ... from BerRunFinish.pm: $OS_ERROR\n\n };
      }

      my $acedb_short_ver = $self->version_lookup($self->acedb_version);
      my $acedb_data_path = $self->{amgap_path}."/Acedb/".$acedb_short_ver."/ace_files/".$self->locus_tag."/".$self->pipe_version;
      unless ( -d $acedb_data_path ) {
	   croak qq{\n\n NO acedb_dir_path, $acedb_data_path, found ... from BerRunFinish.pm: $OS_ERROR\n\n };
      }
      ############################
      # parse the sqlite data file
      ############################

      my $bpnace_fh = IO::File->new();
      my $bpname    = qq{_BER_product_naming.ace};
      my $bpn_file  = qq{$acedb_data_path/$locus_tag$bpname};
      $bpnace_fh->open( "> $bpn_file" )
	  or die "Can't open '$bpn_file', bpn_file for writing ...from BerRunFinish.pm: $OS_ERROR\n\n";

      my $data_fh = IO::File->new();
      $data_fh->open("< $sqlitedatafile")
	  or die "Can't open '$sqlitedatafile',sqlite data file ...from BerRunFinish.pm: $OS_ERROR\n\n";

      while (<$data_fh>) {
	  my ($featname, $proteinname, $genesymbol, $go_terms, $ec_numbers, $t_equivalog, $speciesname ) = split(/\t/,$ARG);
	  print $bpnace_fh "Sequence ", $featname,"\n";
	  print $bpnace_fh "BER_product " ,"\"$proteinname\"","\n\n";
      }
      $bpnace_fh->close();
      $data_fh->close();
      ########################################################
      # write new parse script and parse into acedb via tace
      ########################################################

      $cwd = getcwd();
      my $acedb_maindir_path = $self->{amgap_path}."/Acedb/".$acedb_short_ver;
      unless ($cwd eq $acedb_maindir_path) {
	  chdir($acedb_maindir_path) or die "Failed to change to '$acedb_maindir_path'...  from BerRunFinish.pm: $OS_ERROR\n\n";
      }

      my $acedb_scripts_path = $self->{amgap_path}."/Acedb/Scripts";
      my $parse_script_name  = "parsefiles_wens_".$locus_tag."_".$pipe_version.".sh";
      my $parse_script_full  = qq{$acedb_scripts_path/$parse_script_name};
      my $parse_script_fh    = IO::File->new();
      $parse_script_fh->open("> $parse_script_full")
	   or die "Can't open '$parse_script_full', parse_script_full for writing ...from BerRunFinish.pm: $OS_ERROR\n\n";

      opendir( ACEDATA, $acedb_data_path  ) or die "Can't open $acedb_data_path, acedb_data_path from BerRunFinish.pm: $OS_ERROR\n";

      my @acefiles = ( );
      @acefiles    = readdir(ACEDATA);
      closedir(ACEDATA);

      my $phase5file = $locus_tag."_phase_5_ssid_";

      my $parse = "parse";
      print $parse_script_fh "#!/bin/sh -x\n\n";
      print $parse_script_fh "#if you call script from bash, tace will follow links!\n\n";
      print $parse_script_fh "TACE=/gsc/scripts/bin/tace\n";
      print $parse_script_fh "ACEDB=`pwd`\n\n";
      print $parse_script_fh "export ACEDB\n\n";
      print $parse_script_fh "echo \$acedb\n\n";
      print $parse_script_fh "\$TACE << EOF\n\n";

      my $shortph5file;
      foreach my $acefile (@acefiles){
	  next if $acefile =~ /^\.\.?$/;
	  next if $acefile =~ /\.gff$/;
          next if $acefile =~ /\.txt$/;
	  print $parse_script_fh "$parse  $acedb_data_path/$acefile\n";
	  if ( $acefile =~ /$phase5file/ ) {
	      $shortph5file = $phase5file = $acefile;
	  }
      }
      print $parse_script_fh "\nsave\n";
      print $parse_script_fh "quit\n\n";
      print $parse_script_fh "EOF\n\n";
      print $parse_script_fh "echo \"Parsing of HGMI_$locus_tag $pipe_version files, complete.\" | mailx -s \"HGMI_$locus_tag $pipe_version\" wnash\n";

      $parse_script_fh->close();

      my $mode = 0775;
      chmod $mode, $parse_script_full;
      my $aceparce_stdout = $acedb_data_path."/STDOUT_".$locus_tag."_ace_parse.txt";

      my @aceparcecmd = (
	                 $parse_script_full,
                        );

      IPC::Run::run(
                    \@aceparcecmd,
                     '>',
		    $aceparce_stdout,
                   );

      ########################################################
      # gather stats from phase5 ace file and acedb
      ########################################################
      $phase5file = qq{$acedb_data_path/$phase5file};

      unless (( -e $phase5file ) and ( ! -z $phase5file )) {
	   croak qq{\n\n NO file,$phase5file,(phase5file) found  or else empty ... from BerRunFinish.pm: $OS_ERROR\n\n };
      }

      my $phase5ace_fh = IO::File->new();
      $phase5ace_fh->open("< $phase5file")
	  or die "Can't open '$phase5file', phase5file for reading ...from BerRunFinish.pm: $OS_ERROR\n\n";

      my @phase5acecount = ( );
      while (<$phase5ace_fh>) {
	  chomp $ARG;
	  if ( $ARG =~ /Subsequence/ ) {
	      push (@phase5acecount, $ARG);
	  }
      }
      $phase5ace_fh->close();

      my $acefilecount = scalar(@phase5acecount);

      my $program  = "/gsc/scripts/bin/tace";
      my $db = Ace -> connect (-path    => "$acedb_maindir_path",
			       -program => "$program",
			      ) or die "ERROR: cannot connect to acedb ...from BerRunFinish.pm: $OS_ERROR\n \n";

      my @trna_all_d     = $db->fetch(-query => "Find Sequence $locus_tag\_C*.t* & ! Dead");
      my @rfam_all_d     = $db->fetch(-query => "Find Sequence $locus_tag\_C*.rfam* & ! Dead");
      my @rnammer_all_d  = $db->fetch(-query => "Find Sequence $locus_tag\_C*.rnammer* & ! Dead");
      my @orfs_d         = $db->fetch(-query => "Find Sequence $locus_tag\_C*.p5_hybrid* & ! Dead");

      my $Totals_not_dead      = 0;
      my $Totals_not_dead_rna  = 0;
      my $Totals_not_dead_orfs = 0;

      $Totals_not_dead      = scalar(@rfam_all_d) + scalar(@rnammer_all_d) + scalar(@trna_all_d) + scalar(@orfs_d);
      $Totals_not_dead_rna  = scalar(@rfam_all_d) + scalar(@rnammer_all_d) + scalar(@trna_all_d);
      $Totals_not_dead_orfs = scalar(@orfs_d);

      my @trna_all     = $db->fetch(-query => "Find Sequence $locus_tag\_C*.t*");
      my @rfam_all     = $db->fetch(-query => "Find Sequence $locus_tag\_C*.rfam*");
      my @rnammer_all  = $db->fetch(-query => "Find Sequence $locus_tag\_C*.rnammer*");
      my @orfs         = $db->fetch(-query => "Find Sequence $locus_tag\_C*.p5_hybrid*");

      my $Totals_with_dead      = 0;
      my $Totals_with_dead_rna  = 0;
      my $Totals_with_dead_orfs = 0;

      $Totals_with_dead      = scalar(@rfam_all) + scalar(@rnammer_all) + scalar(@trna_all) + scalar(@orfs);
      $Totals_with_dead_rna  = scalar(@rfam_all) + scalar(@rnammer_all) + scalar(@trna_all);
      $Totals_with_dead_orfs = scalar(@orfs);

      print "\n\n".$locus_tag."\n\n";
      print $acefilecount."\tSubsequence counts from acefile $shortph5file\n\n";
      print $Totals_not_dead."\tp5_hybrid counts from ACEDB  orfs plus RNA's that are NOT dead genes\n";
      print $Totals_not_dead_rna."\tp5_hybrid counts from ACEDB for ALL RNA's that are NOT dead genes\n";
      print $Totals_not_dead_orfs."\tp5_hybrid counts from ACEDB orfs minus RNA's that are NOT dead genes\n\n";
      print $Totals_with_dead."\tp5_hybrid counts from ACEDB orfs plus RNA's with dead genes (should match acefile $shortph5file)\n";
      print $Totals_with_dead_rna."\tp5_hybrid counts from ACEDB for ALL RNA's with dead genes\n";
      print $Totals_with_dead_orfs."\tp5_hybrid counts from ACEDB orfs with dead genes\n\n";

      if ( $acefilecount == $Totals_with_dead ){

	  print "p5_hybrid ace file counts match p5_hybrid counts in ACEDB... Good :) \n\n";

      }
      else{

	  print "HOUSTON, WE HAVE A PROBLEM, p5_hybrid ace file counts DO NOT MATCH p5_hybrid counts in ACEDB (Totals_with_dead)... BAD :(\n\n";

      }
      ########################################################
      # Writing the rt file
      ########################################################

      my $rtfilename = $project_type."_rt_let_".$locus_tag."_".$pipe_version.".txt";
      my $rtfileloc  = $amgap_path."/Acedb/Scripts/".$project_type."_files";
      my $rtfullname = qq{$rtfileloc/$rtfilename};
      my $rtfile_fh  = IO::File->new();
      $rtfile_fh->open("> $rtfullname")
	   or die "Can't open '$rtfullname', rtfullname for writing ...from BerRunFinish.pm: $OS_ERROR\n\n";

      print $rtfile_fh qq{\n$assembly_name, $locus_tag, a $project_type project has finished processing in AMGAP, BER product naming and now ready to be processed for submissions\n\n};

      my $sequence_set     = BAP::DB::SequenceSet->retrieve($ssid);
      my $software_version = $sequence_set->software_version();
      my $data_version     = $sequence_set->data_version();

      print $rtfile_fh qq{BAP/MGAP Version: $software_version }, "\n";
      print $rtfile_fh qq{Data Version: $data_version}, "\n\n";
      print $rtfile_fh qq{Location:\n\n};

      my $location = $amgap_path."/".$org_dirname."/".$assembly_name."/".$pipe_version;

      print $rtfile_fh qq{$location\n\n};
      print $rtfile_fh qq{Gene prediction by the following programs has been run via bap_predict_genes:\n\n};
      print $rtfile_fh qq{Glimmer3\n};
      print $rtfile_fh qq{GeneMark\n};
      print $rtfile_fh qq{trnascan\n};
      print $rtfile_fh qq{RNAmmer\n};
      print $rtfile_fh qq{Rfam v8.1, with Rfam_product\n\n};
      print $rtfile_fh qq{bap_merge_genes has been run and includes blastx through phase_5\n\n};
      print $rtfile_fh qq{Here are the gene counts from Oracle AMGAP:\n\n};

      my @sequences        = $sequence_set->sequences();
      my $blastx_counter   = 0;
      my $glimmer2_counter = 0;
      my $glimmer3_counter = 0;
      my $genemark_counter = 0;

      foreach my $i (0..$#sequences){
	  my $sequence      = $sequences[$i];
	  my @coding_genes = $sequence->coding_genes();
	  foreach my $ii (0..$#coding_genes){
	      my $coding_gene = $coding_genes[$ii];
	      if ($coding_gene->source() =~ 'blastx'){
		  $blastx_counter++;
	      }
	      elsif($coding_gene->source() =~ 'glimmer3'){
		  $glimmer3_counter++;
	      }
	      else{
		  $genemark_counter++;
	      }
	  }
      }

      print $rtfile_fh qq{blastx count   =\t $blastx_counter},"\n";
      print $rtfile_fh qq{GeneMark count =\t $genemark_counter},"\n";
      print $rtfile_fh qq{Glimmer3 count =\t $glimmer3_counter},"\n\n";
      print $rtfile_fh qq{Protein analysis by the following programs has been run via PAP workflow:\n\n};
      print $rtfile_fh qq{Interpro\n};
      print $rtfile_fh qq{Kegg\n};
      print $rtfile_fh qq{psortB\n};
      print $rtfile_fh qq{Blastp\n\n};
      print $rtfile_fh qq{Location of AMGAP ace files can be located, here:\n\n};
      print $rtfile_fh qq{$acedb_data_path\n\n};

      foreach my $acefile (@acefiles){
	  next if $acefile =~ /^\.\.?$/;
	  next if $acefile =~ /\.gff$/;
          next if $acefile =~ /\.txt$/;
	  print $rtfile_fh "$acefile\n";
      }

      print $rtfile_fh qq{\n$locus_tag, QC ace file gene counts verses ACEDB gene counts},"\n\n";
      print $rtfile_fh qq{$acefilecount\tgenes from acefile $shortph5file},"\n\n";
      print $rtfile_fh qq{$Totals_not_dead\tp5_hybrid genes from ACEDB orfs plus RNA\'s that are NOT dead genes},"\n";
      print $rtfile_fh qq{$Totals_not_dead_rna\tp5_hybrid genes from ACEDB for ALL RNA\'s that are NOT dead genes},"\n";
      print $rtfile_fh qq{$Totals_not_dead_orfs\tp5_hybrid genes from ACEDB orfs minus RNA\'s that are NOT dead genes minus RNA\'s},"\n\n";
      print $rtfile_fh qq{$Totals_with_dead\tp5_hybrid genes from ACEDB orfs plus RNA\'s with dead genes (should match acefile $shortph5file ) },"\n";
      print $rtfile_fh qq{$Totals_with_dead_rna\tp5_hybrid genes from ACEDB for ALL RNA\'s with dead genes},"\n";
      print $rtfile_fh  qq{$Totals_with_dead_orfs\tp5_hybrid genes from ACEDB orfs with dead genes minus RNA\'s},"\n\n";

      if ( $acefilecount == $Totals_with_dead ) {
	  print $rtfile_fh qq{p5_hybrid ace file counts match p5_hybrid counts in ACEDB... Good :) },"\n\n";
      }
      else{
	  print $rtfile_fh qq{HOUSTON, WE HAVE A PROBLEM, p5_hybrid ace file counts DO NOT MATCH p5_hybrid counts in ACEDB (Totals_with_dead)... BAD :\(  }, "\n\n";
      }
      print $rtfile_fh qq{Location of this file:\n};
      print $rtfile_fh qq{\n$rtfullname\n\n};
      print $rtfile_fh qq{I am transferring ownership to Veena.\n\n};
      print $rtfile_fh qq{Thanks,\n\n};
      print $rtfile_fh qq{Bill\n};

      send_mail(
	        $ssid,
		$assembly_name,
		$rtfileloc,
		$rtfilename,
		$rtfullname
               );

      return 1;
  }


################################################
################################################

sub version_lookup
{
    my $self   = shift;
    my $v      = shift;
    my $lookup = undef;
    my %version_lookup = (
                          'V1' => 'Version_1.0', 'V2' => 'Version_2.0',
			  'V3' => 'Version_3.0', 'V4' => 'Version_4.0',
			  'V5' => 'Version_5.0', 'V6' => 'Version_6.0',
			  'V7' => 'Version_7.0', 'V8' => 'Version_8.0',
		         );

    if(exists($version_lookup{$v}))
    {
        $lookup = $version_lookup{$v};
    }

    return $lookup;
}

sub send_mail {

    my ($ssid, $assembly_name, $rtfileloc, $rtfilename, $rtfullname) = @ARG;

    my $from = join(
                    ', ',
                    'wnash@watson.wustl.edu'
                   );

    my $to   = join(
                    ', ',
                    'wnash@watson.wustl.edu',
		    'kpepin@watson.wustl.edu',
                   );

    my $subject = "Amgap BER Product Naming script mail for AMGAP SSID: $ssid ($assembly_name)";

    my $body = <<BODY;
The Amgap BER Product Naming script has finished running for MGAP SSID: $ssid ($assembly_name).
The information for the rt ticket has been attached:

File: $rtfilename

Path: $rtfileloc
BODY

   my $msg = MIME::Lite->new(
                              From      => $from,
                              To        => $to,
                              Subject   => $subject,
                              Data      => $body,
                          );
    $msg->attach(
                 Type        => "text/plain",
		 Path        => $rtfullname,
		 Filename    => $rtfilename,
		 Disposition => "attachment",
                );
    
$msg->send();
    
}

1;
