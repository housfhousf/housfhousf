#!/usr/bin/perl
$r0=qr/(\$|exec[\s]+sql[\s]+)/is;
$r= qr/^[^\$'"]*$r0/is;
$r1=qr/$r0(select|insert|delete|update|create|prepare|declare|fetch|open|free|close|execute|grant|set)\s+/is;
$type=qr/(static|const|char|int|float|double|date|long|dec_t|short|typedef)\W/is;
$itype=qr/^[#\$]\s*(define|undef|if|else|end|include|$type)\W/is;

#**************************************
sub do_a_statement{
    my $in=$_[0]; my $k;
    my $k; my $p1;my $p0;my $pp;
    if($in =~ m/\W+parameter\s+$type/is){
	        $in =~ s/parameter\s+//is;
	        return $in;
    }
    if($in =~ $itype)  {  
      @matches=$in=~ m/\$/g;
			my $count=scalar @matches;
		  if($count<2){
    		return $in;
    	}
    	
    }
    if($in =~ m{^\W*$}){  return $in;}
    ####### matches 
    if($in =~ m/matches/is){
            $p1=$'; $p0=$`; $pp=$&;
            $p1=~s/\*%s/%%%s/g;
            $p1=~s/\*/%/g;
            $in=$p0.$pp.$p1;
            $in=~s/matches/like/g;
    }  
   	
    if($in =~ $r1 or 
       $in =~ $r ){
       $p1=$'; $p0=$`; $pp=$&;
    }else {  	return $in; }
   
    if($p1=~s/\$/:/g){  # �N $hostvar �令 :hostvar
          $in=$p0.$pp.$p1;
    }
    $in=~s/$r0/EXEC SQL /i ;
    ####### �N�@�ӥ���ťէ令 ��ӥb���ť�
    $in=~s/�@/  /g;
    ####### �N //... �令�@/*...*/
    if($in =~ m{//(.*?)(\n)}is){
       	$p1=$'; $p0=$`; $remark=$&;
            $remark = "/*".$1."*/\n";
        $in=$p0.$remark.$p1;
    }
    ####### �N����s���Ÿ� \ �h��
    if($in=~ s/\\\n/\n/isg){
       	$p1=$'; $p0=$`; $remark=$&;
	  my $k= $1;
    }

    if($in =~ m/select(.+?)unique(.+?)from/is){
       $in =~ s/unique/distinct/isg;
    }
    if($in =~ m/select\s+first\s+(\d+)(.*)/is){
            $p1=$';
            $p0=$`;
            $pp="select".$2." limit ".$1;
            $in=$p0.$pp.$p1;
    }
 
    if($in =~ m/$r0/is){
    	$p1=$'; $p0=$`; $pp=$&;
    	$p1=~s/"/'/g;
      $in=$p0.$pp.$p1;
    }
    return $in;
}
#**************************************
sub do_a_post_statement{
    my $p;my $p1;my $p0;my $pp;
    $p=$_[0];
    ####### with no log
    $p=~ s/with\s+no\s+log//is;
    if($p =~ m/declare\s+(\S+)\s+.*cursor/is){
				$delcare{$1}=1;
    } 
    if($p =~ m/exec sql fetch\s+(?:.*\s+)(\S+)\s+into.*$/is){
				if ( ! defined $delcare{$1}){
					   $p1=$'; $p0=$`; $pp=$&;
       			$p=$p0."\n/* PostgreSQL curosr $1 �٥�declare\n.$pp.\n�ݧ�g��PostgreSQL */\n".$p1;

			  }
			  $p=~s/\s+fetch\s+previous\s+/ fetch backward /is;S
    } 
    ####### fetch previous �ݧ令 fetch backward
    
    ####### other DB 
    if($p=~m/(alltrunk:|edtrunk:|workbase:|userbase:)/is){
    	my $k=$1;
			my $k0=$k;
    	$k=~s/:/./;
    	$p=~s/$k0/$k/g;
    }
   
    ####### SQL EXEC
    if($p !~ m/EXEC SQL/is){
	      return $p;
    }
    ####### �B�z group��� 
    while($p=~m/([^\w"\$:])group(\W|$)/is){
        	$p1=$'; $p0=$`; $pp=$1.'"group"'.$2;
        	$p =$p0.$pp.$p1;
    }
    $p=~s/["]group["]\s+by/group by/isg;
    ####### �ഫ SET LOCK MODE TO WAIT
    if($p =~ m/SET\s+LOCK\s+MODE\s+TO\s+WAIT\s+(\d+)/is){
         	$p1=$'; $p0=$`; $pp="set lock_timeout = '$1s'";
        	$p =$p0.$pp.$p1;   
    }
    ####### Current  �ݧ令 CURRENT_TIMESTAMP
		if($p=~m/(select|update|insert)/is){
    	 while($p=~m/([^\w"\$:])current(\W|$)/is){
        	$p1=$'; $p0=$`; $pp=$1.'CURRENT_TIMESTAMP'.$2;
        	$p =$p0.$pp.$p1;
    }}
    #### �L�k�B�z
    if($p=~m/$r0.*(execute procedure|into temp|dirty read|rename column|alter table).*$/is or 
       $p=~m/EXEC SQL.*:\w+(\[\w*\])+\W*.*$/is){
    	 $p1=$'; $p0=$`; $pp=$&;
       $p=$p0."\n/* �ݧ�g��PostgreSQL \n.$pp.\n�ݧ�g��PostgreSQL */\n".$p1;
    }
    return $p;
 }
# **************************************
sub file_sub{
    print "#################### \n";
    my $p1;my $p0;my $pp;my $po; 
    $source=$_[0];
    @list = split '/' , $source;
    $name = pop(@list);
    if($name=~ m/[.]ec$/){
    	 $name=$`;
    }
    $tmp="/tmp/$name.ec";
    $diff="/tmp/$name.diff";
    $pgc="$name.pgc";

    open(my $fh,'<',$source)or die "Cannot open file: $!";
    open(my $fd,'>',$diff)  or die "Cannot open file: $!";
		open(my $fo,'>',$tmp) 	or die "Cannot open file: $!";
 		open(my $fg,'>',$pgc) 	or die "Cannot open file: $!";
   $line=0;
    while (my $n=<$fh>){
       my $in=$_=$old=$po=$n;
       my $mno=1;
       ####### Coment ���R
       if ($in =~ m{^\s*//(.*)} ){  goto END_LINE;}
       if ($in =~ m{^\s*/\*}s) {
         while (($in !~ m{\*/}s) and ($n= <$fh>)){
              $in=$in. $n;
         };
	 			 $old=$po=$in;
         goto END_LINE;
       }
       if($in =~ m/\W+parameter\s+$type/is){
	        $in =~ s/parameter\s+//is;
	        $po = $in;
       }
       if($in =~ m{^\W*$})  {  		   goto END_LINE;}
       if($in =~ m{^\s*[#]}){  		   goto END_LINE;}
       if($in =~ m/^\W*\w+struct/){  goto END_LINE;}
       if($in =~ m/^\W*$type/){  	   goto END_LINE;}
       if($in =~ m/^\W*$itype/)  {   goto END_LINE;}
 			 ########### �B�z����
       while(($in !~ m/\;/s) and ($n= <$fh>)){
              $in=$in. $n;
              $mno++;
       };
       $old=$po=$in;      
       my $out;
       my @x=split(/;/,$in,-1);
       my $no=$#x;
       my $do=1;
       for (my $i = 0; $i <=$ no; $i++) {
            my $s=@x[$i];
            $s=&do_a_statement($s);
            
 GlueColumn:
            if($i>0){
                $out=$out.";".$s;
            }else{
                $out=$s;
            }
       }
 			 if(defined($out)){
 			 	 $in=$out;
 			 }
 			 ########################
       $po=do_a_post_statement($in);
END_LINE:
       print $fo $in;
       print $fg $po;
       if($po eq $old){ next; }
        $line+=$mno;
        print $fd '<'.$..': '.$old;
        print $fd '>'.$..': '.$in;
 				
    }
    close   $fh;    close   $fd;  close   $fo; close $fg;
    system("rm -f $name.c $name.o $name.err");
    print   "$tmp �����L���зǪ� SQL C�{�� \n";
    print   "$pgc �����L��PostgreSQL C�{�� \n";
    print		"$diff ��EC �P PGC�t�����B \n";
    print   "�ר�O�Ƶ���/*�ݧ�g��PostgreSQL*/���r��,�����h��g��\n";
    print 	"½Ķ�i��|���~,�аȥ��Բ�����,�ñN���~�a��ۦ�� \n";
    print 	"$pgc �`�@���F $line ��{�� \n";
    system("ecpg -C INFORMIX $pgc >$name.err 2>&1");
    if(!-e "$name.c"){
      print "$pgc �L�k����$name.c �Ь�$name.err ��{�� \n";
      return -1;
    }
    system("cc -I /usr/include/postgresql -c $name.c 2>$name.err");
    if(-e "$name.o"){
      print "�w�i���� $name.o  \n";
      print "***************************\n";
      system("rm $name.err");
      if(-e "$name.ec"){
      	system("rm $name.c");
      }
      return 0;
    }
    print "$pgc �L�k����$name.o �Ь�$name.err ��{�� \n";
};
# **************************************
while($source = shift @ARGV){

    &file_sub($source);
};

