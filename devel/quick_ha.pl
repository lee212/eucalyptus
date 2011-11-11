#!/usr/bin/perl

@hosts=undef;
%host_cloud_map=undef;
%host_cc_map=undef;
%host_nc_map=undef;
$out_file="/tmp/quick_ha.out";
$err_str=undef;
$root_dir="/root"; $euca_dir="/opt/eucalyptus";

sub print_usage {
   print "./quick_ha.pl [list of hosts to test]\n";
   print "example: ./quick_ha.pl 192.168.23.71 192.168.23.73\n";
}

sub parse_args {
    @hosts=split(/[\s]/,"@_");
}

sub read_output {
    open FH, "$out_file"; # or {print "can't open the file $out_file\n"; return 1};
    my @lines = <FH>;
    close FH;
    @lines = "@lines"."\n";
}

sub ssh_success {
   my $host=$_[0];
   my $cmd=$_[1];

   my $sshcmd = "ssh "."root\@$host"." \"".$cmd." >/dev/null 2>&1\"";
   $rc = system($sshcmd);
   if($rc){
       return 0;
   }else{
       return 1;
   }
}

sub host_ready{
   my $host=$_[0];
   if(!ssh_success($host, "ls $root_dir/eucarc")){
      return 0;}
   if(!ssh_success($host, "ls $euca_dir")){
      return 0;}
   return 1;
}

$source_eucarc=1;
sub ssh_stdout {
    my $host=$_[0];
    my $cmd=$_[1];
   
    if($source_eucarc){
       $cmd="source $root_dir/eucarc >/dev/null 2>&1; ".$cmd; 
    }
  
    my $sshcmd = "ssh "."root\@$host"." \"".$cmd."\" > ".$out_file." 2>&1";
    $rc = system("rm -f $out_file");
    $rc = system($sshcmd);
    if($rc){
       if (-e $out_file){
          my @output = &read_output;
          return ($rc, "@output");
       }else{
          return ($rc, "");
       }
    }else
    {
          my @output= &read_output;
          return (0, "@output");
    }
}


sub is_cloud {
   return &ssh_success($_[0], "ps afx | grep eucalyptus-cloud | grep -v \'grep\'");
}
sub is_cc {
   return &ssh_success($_[0], "ps afx | grep httpd-cc | grep -v \'grep\'");
}
sub is_nc {
   return &ssh_success($_[0], "ps afx | grep httpd-nc | grep -v \'grep\'");
}

sub get_topology {
   foreach $h (@hosts){
         if(not host_ready($h))
         {
             print "Host $h is not ready (check eucarc and EUCALYPTUS installation)\n";
             next;
         }
         print "host $h runs [";
         if(is_cloud($h)){
            $host_cloud_map{$h}=1;
            print "CLC ";
         }
         if(is_cc($h)){
            $host_cc_map{$h}=1;
            print "CC ";
         }
         if(is_nc($h)){
            $host_nc_map{$h}=1;
            print "NC ";
         }
         print "]\n"; 
   }
}

$test_idx=1;
%test_phases=undef;
sub test_start{
   $test_phases{$test_idx}=$_[0];
   print "####################### T$test_idx: ".$_[0]." #########################\n\n";
}

sub test_end{
   print "#################### END T".$test_idx.": ".$test_phases{$test_idx}." ######################\n\n";
   $test_idx++;
}

sub run_on {
    my $cmd=$_[0];
    my $err_msg=$_[1];
    my %map=%{$_[2]};

    foreach $h (keys %map) {
      if (not defined $map{$h}){ next;}
      ($rc, $stdout) = &ssh_stdout($h,$cmd);

      if($rc){
           print "[$h] $err_msg\n";
      }else{
           print "[$h] =>\n".$stdout;
      }
    }
}

sub run_on_clc {
    &run_on($_[0],$_[1],\%host_cloud_map);
}

sub run_on_cc {
    &run_on($_[0],$_[1],\%host_cc_map);
}

sub run_on_nc {
    &run_on($_[0],$_[1],\%host_nc_map);
}

######## MAIN #############
parse_args @ARGV;
if(not defined($hosts[0] ))
{
   &print_usage;
   exit 1;
}
get_topology;
print "Do you want to continue? (yes/no)\n";
chomp($answer=<STDIN>);
if( not $answer =~ /yes/){
    print "bye bye \n";
    return 1;
}

require "./quick_cloud.pl";
require "./quick_cc.pl";
require "./quick_nc.pl";
