%{
	#include <stdlib.h>
	#include <stdio.h>
	#include <string.h>
	
	int lineno=1;
	int n,TypeFlag=1; 			//typeflag default to okay ie., every thing's fine
	
	#define DUMMY "Dummy"
	#define _Varlist 12
	#define _StmtList 13
	#define _Var 14
	#define _GDefList 15
	#define _Program 19
	#define _Truth 20
	#define _mod 25
	#define ARRAY 34
	#define FUNC 35
	#define _ArgList 36
	#define _Arg 37
	#define _GIdList 38
	#define _List 39
	#define _LDefList 40
	#define _LIdList 41
	#define _Fdeflist 42
	#define _Fdef 43
	#define _ARG_LVAR 44
	#define _junc 45
	#define HEAD 1
	#define L_HEAD 0
	#define _body 46
	#define _ExpList 47
	#define _main 48
	#define _pointer 49

	int POINT = 5;
	#include "table2.c"
	#include "tree2.c"
	#define getline() printf("Error at %d\n",lineno);
	

	int agcount =1;

	//===GLOBAL VARIABLES used in codegen part

	//reg call count
	int regCallCount = 0;

	int regStack[8] = {-1,-1,-1,-1,-1,-1,-1,-1};
	

	//for label generation
	int Label=0;

	//free reg after completion of its requirement
	int RegNo = -1;	//range 0-7

	//use and increase to size
	int LocNo = 0;	//range 0-25

	int BP = 0;
	int SP = 0;

	//============================================


	FILE * fp;
	char * current_func;
	void evalDecl(int flag ,struct node *nd,int i,char * name);
	void flush_local();
	void ret_check(int i,struct node * nd);
	void install_args_to_locals(int i,struct node * nd);
	void push_list(struct node * nd);
	void pop_list(struct node * nd);
	void func_code_gen(int i,struct node * nd);
	void err_arg(int i,struct node * nd);
	void alloc_mem_for_func_locals(struct node * nd);
	void bind_locals_to_mem(int i,struct node * nd);
	void freeReg(int r,struct node * nd);
	void local_bind_count_init();
	int get_local_bind_count();
	void arg_bind_count_init();
	int get_arg_bind_count();

//void func_init(struct node * ) ask anoosh abt this #args list struct in c lang


void main_init(struct node * nd){
		if(TypeFlag==0) {printf("Exit status = failure\n");exit(0);}
		print_table();	
		int foo = fprintf(fp,"START\n");
		///fprintf(fp,"MOV BP, 0\n");
		//fprintf(fp, "MOV SP,BP\n" );
		fprintf(fp,"MOV BP, %d\n",LocNo-1);
		fprintf(fp,"MOV SP,BP\n");
		printf("Initial BP is at %d\n",LocNo-1);
		//fprintf(fp,"PUSH BP\n");
		int m = local_head->bind;	
		int r = getReg();
		int r1 = getReg();
		fprintf(fp, "MOV R%d,%d\n",r,m );
		fprintf(fp, "MOV R%d,SP\n",r1 );
		fprintf(fp, "ADD R%d,R%d\n",r,r1 );
		fprintf(fp,"MOV SP,R%d\n",r);
		freeReg(r1,NULL);
		freeReg(r,NULL);
		CodeGen(nd);
		foo = fprintf(fp,"HALT");
		int z= fclose(fp);
		print_table();
		exit(1);
}

void error(int i){
	getline();
	switch(i){
		case 1: {printf("Undeclared Variable\n");break;}
		case 2: {printf("Redeclared Variable\n");break;}
		case 3: {printf("Expected int\n");break;}
		case 4: {printf("Expected bool\n");break;}
		case 5: {printf("Type Mismatch\n");break;}
		case 6: {printf("Return type error\n");break;}
		case 7: {printf("Undeclared function\n");break;}
		case 8: {printf("redeclared function\n");break;}
		case 9: {printf("arguments mismatch\n");break;}
		case 10:{printf("argument pointer error\n");break;}
	}
	exit(1);
}
//for pointeres from callee perspective
int get_pointer_val(char* _name){
	int r  = get_pointer_addr( _name);
	fprintf(fp,"MOV R%d,[R%d]\n",r,r);
	return r;
}

int get_pointer_addr(struct node * nd){
	int r = getReg();
	int r1 = getReg();
	int flag = 0;		//to distinguish from global to local -- BP issue in global
	struct gnode * temp;
	temp = fetch(head,nd->varname);
	if(temp == NULL) temp = fetch(local_head,nd->varname);
	else flag =1;
	if(temp  ==  NULL) {error(10);}
	int m = temp->bind;
	fprintf(fp,"MOV R%d,%d\n",r,m);
	if(nd->left) {
		int r2 = CodeGen(nd->left);
		fprintf(fp,"ADD R%d,R%d\n",r,r2);
		freeReg(r2,nd);
	}
	fprintf(fp,"MOV R%d,0\n",r1);
	if(flag!=1) fprintf(fp,"MOV R%d,BP\n",r1);
	fprintf(fp,"ADD R%d,R%d\n",r,r1 );
	freeReg(r1,NULL);
	return r;
}

%}


%union {
	int val;
	char* id;
	struct node *ptr;
}


%token <id>  ID


%token <val> INT
%token <val> WRITE 
%token <val> READ
%token <val> IF THEN ELSE ENDIF
%token <val> WHILE DO ENDWHILE
%token <val> EQEQ
%token <val> INTEGER
%token <val> MAIN EXIT
%token <val> SILBEGIN END
%token <val> DECL ENDDECL RET
%token <val> GBOOL GINT INTD BOOLD
%token <val> TRUE
%token <val> FALSE
%token <val> LE GE NE
%token <val> AND OR NOT



%type <ptr> Program  Mainblock
%type <ptr> StmtList  Stmt Expr item
%type <ptr>  Var ArgList Arg List Expr1
%type <ptr> FdefList Fdef Body ExpList
%type <ptr> LDefblock LDefList LDecl  LIdList retExp
%type <ptr> GDefblock GDefList GIdList GDecl GId


%left OR
%left AND 
%left '!'
%left '+' '-'
%left '*' '/' '%'
%nonassoc '<'
%nonassoc '>' LE NE GE
%nonassoc EQEQ 


%%
Program: GDefblock FdefList Mainblock	{	$$ = $3;
											main_init($3);
											printf("Exit");
											exit(1);
									
								}
	 |GDefblock  Mainblock	{		$$ = $2;
									main_init($2);
									printf("Exit");
									exit(1);
								}
	;
GDefblock : DECL GDefList ENDDECL	{$$=$2;fp= fopen("outfile.txt","w+");print_table();}
		;
GDefList : GDefList GDecl 	{$$=makenode($1,$2,_GDefList,0,DUMMY);}
		| GDecl				{$$=$1;}
		;
GDecl   : GINT GIdList ';'	{$$=$2; evalDecl(HEAD,$2,0,DUMMY); }
		| GBOOL GIdList ';'	{$$=$2; evalDecl(HEAD,$2,1,DUMMY); }		
		;
GIdList :	GIdList ',' GId  {$$=makenode($1,$3,_GIdList,0,DUMMY);}
		| GId 				 {$$=makenode(NULL,$1,_GIdList,0,DUMMY);}
		;
GId : ID 					{$$=makenode(NULL,NULL,ID,0,$1);}
	| ID '[' Expr ']'		{$$=makenode($3,NULL,ARRAY,0,$1);
							/*MOD : make "expr" integer in grammar*/}
	| ID '(' ArgList ')'   	{$$ = makenode($3,NULL,FUNC,0,$1);



							flush_local();}
	| ID '(' ')'			{$$ = makenode(NULL,NULL,FUNC,0,$1);}
	;
ArgList : ArgList ';' Arg 	{$$ = makenode($1,$3,_ArgList,0,"_ArgList");/*when func is called called*/install_args_to_locals(-1,$$);}
		| Arg 				{$$ = makenode($1,NULL,_ArgList,0,"_ArgList");install_args_to_locals(-1,$1);}
		;
Arg : GINT List 				{$$ = makenode($2,NULL,GINT,0,"arg");}
	| GBOOL List 			{$$ = makenode($2,NULL,GBOOL,0,"arg");}
	;		
List : List ',' item		{$$ = makenode($1,$3,_List,0,"list");}
	| item					{$$ = makenode(NULL,$1,_List,0,"list");}
	;
item 	:  ID 				{$$ = makenode(NULL,NULL,ID,0,$1);}
		|  '&' ID 			{$$ = makenode(NULL,NULL,_pointer,0,$2);/*new change*/}
		;
FdefList : FdefList Fdef 	{$$ = makenode($1,$2,_Fdeflist,0,"Fdeflist");}
		| Fdef 				{$$ = makenode(NULL,$1,_Fdeflist,0,"Fdeflist");}
		;
Body : StmtList retExp 		{$$ = makenode($1,$2,_body,0,"Body");}
	|	retExp				{$$ = makenode(NULL,$1,_body,0,"Body");}
	;
Fdef : GINT ID '(' ArgList ')' '{' LDefblock SILBEGIN Body END  '}'  
							{	/*MOD : Fdef  <-- stmtlist     (improves tree)*/
								//flush_local();
								ret_check(0,$9->right);
								
								int t = func_check1(0,$2,$4);
								if(t !=-1  ) {getline();TypeFlag=0;}

								struct gnode * temp = fetch(head,$2);
								//temp->flabel = Label; Label++;
								
								$$ = makenode($9,makenode($4,$7,_junc,0,DUMMY),_Fdef,temp->flabel,$2);	//NEW : right child
								func_code_gen(0,$$);
								flush_local();
							}

	 | GBOOL ID '(' ArgList')' '{' LDefblock SILBEGIN Body END  '}' 
							{	
								//flush_local();
								ret_check(1,$9->right);

								int t = func_check1(1,$2,$4);
								if(t !=-1  ) {getline();TypeFlag=0;}

								struct gnode * temp = fetch(head,$2);
								//temp->flabel = Label; Label++;

								$$ = makenode($9,makenode($4,$7,_junc,1,DUMMY),_Fdef,temp->flabel,$2);	//NEW : right child
								func_code_gen(1,$$);

								flush_local();
							}

	 | GINT ID  '('  ')' '{' LDefblock SILBEGIN  Body END  '}'
	 						{
	 							//flush_local();
	 							ret_check(0,$8->right);

	 							int t = func_check1(0,$2,NULL); 
								if(t !=-1  ) {getline();TypeFlag=0;}

	 							struct gnode * temp = fetch(head,$2);
								//temp->flabel = Label; Label++;

	 							$$ = makenode($8,makenode(NULL,$6,_junc,1,DUMMY),_Fdef,temp->flabel,$2);	//NEW : right child
	 							
	 							func_code_gen(0,$$);

								flush_local();

	 						}

	 | GBOOL ID '('  ')' '{' LDefblock SILBEGIN Body END  '}'
	 						{
	 							//flush_local();
	 							ret_check(1,$8->right);

	 							int t = func_check1(1,$2,NULL);		
								if(t !=-1  ) {getline();TypeFlag=0;}

	 							struct gnode * temp = fetch(head,$2);
								//temp->flabel = Label; Label++;

	 							$$ = makenode($8,makenode(NULL,$6,_junc,1,DUMMY),_Fdef,temp->flabel,$2);	//NEW : right child
	 							
	 							func_code_gen(1,$$);

								flush_local();
							}
	 ;

retExp : RET Expr ';'  {$$ = makenode($2,NULL,RET,0,DUMMY);}
		;

LDefblock 	: DECL LDefList ENDDECL   {$$ = $2;evalDecl(L_HEAD,$2,0,DUMMY);}

LDefList	:LDefList LDecl {$$ = makenode($1,$2,_LDefList,0,"LDefList");}
			| LDecl			{$$ = makenode(NULL,$1,_LDefList,0,"LDefList");printf("--------------------------\n");}
			;

LDecl 	: GINT LIdList ';'	{$$ = makenode($2,NULL,GINT,0,"Gint");/*flush_local();/*evalDecl(L_HEAD,$2,0,DUMMY);*/}
		| GBOOL LIdList ';'	{$$ = makenode($2,NULL,GBOOL,0,"Gbool");/*flush_local();/*evalDecl(L_HEAD,$2,0,DUMMY);*/}
		;

LIdList : LIdList ',' ID 	{$$ = makenode($1,makenode(NULL,NULL,ID,0,$3),_LIdList,0,DUMMY);}
		| ID 				{$$ = makenode(NULL,makenode(NULL,NULL,ID,0,$1),_LIdList,0,DUMMY);}
		;	

Mainblock : MAIN  '{' LDefblock SILBEGIN StmtList retExp END  '}'	{$$ = $5;//BP = LocNo -1; SP = BP;
																	flush_local();ret_check(0,$6);
																	local_bind_count_init();
																	bind_locals_to_mem(-1,$3);			//generate local_table for main
																	printf("\nMAIN LOCAL TABLE \n");
																	print_locals();
																	alloc_mem_for_func_locals($$);
																	}
		|  MAIN  '{'  SILBEGIN StmtList retExp END  '}'	{$$ = $4;
													flush_local();ret_check(0,$5);
													local_bind_count_init();
													//bind_locals_to_mem(-1,$3);
													printf("\nMAIN LOCAL TABLE \n");
													print_locals();
													alloc_mem_for_func_locals($$);
													//local_head is null
													}
		;


StmtList: Stmt 				{$$=$1;}
	| StmtList Stmt 		{$$=makenode($1,$2,_StmtList,0,DUMMY);}
	;


Stmt : WRITE '(' Expr ')' ';'	
	{$$=makenode($3,NULL,WRITE,0,"Write"); type_check2($$);}

	| READ '(' Var ')' ';'
	{$$=makenode($3,NULL,READ,0,"Read"); type_check2($$);}
	
	| IF '(' Expr ')' THEN StmtList ENDIF ';'
	{$$=makenode($3,$6,IF,0,"If");     type_check2($$);}

	| IF '(' Expr ')' THEN StmtList ELSE StmtList ENDIF ';'
	{ $$=makenode($3,makenode($6,$8,ELSE,0,"Else"),IF,0,"If");  type_check2($$);}


	| WHILE '(' Expr ')' DO StmtList ENDWHILE ';'	
	{$$=makenode($3,$6,WHILE,0,"While"); type_check2($$);}

	| Var '=' Expr ';'
	{$$=makenode($1,$3,'=',0,"=");	type_check2($$);}

	;



Expr  : Expr '<' Expr    	{$$=makenode($1,$3,'<',0,DUMMY); /*err_arg(1,$$);*/}
		| Expr '>' Expr    	{$$=makenode($1,$3,'>',0,DUMMY); /*err_arg(1,$$);*/}
		| Expr GE Expr   	{$$=makenode($1,$3,GE,0,DUMMY);	 /*err_arg(1,$$);*/}
		| Expr LE Expr    	{$$=makenode($1,$3,LE,0,DUMMY);	 /*err_arg(1,$$);*/}	
		| Expr NE Expr   	{$$=makenode($1,$3,NE,0,DUMMY);	 /*err_arg(1,$$);*/}
		| Expr EQEQ Expr   	{$$=makenode($1,$3,EQEQ,0,DUMMY);/*err_arg(1,$$);*/}
		| '!' Expr  		{$$=makenode($2,NULL,NOT,0,DUMMY);/*err_arg(1,$$);*/}
		| Expr AND Expr		{$$=makenode($1,$3,AND,0,DUMMY); /*err_arg(1,$$);*/}
		| Expr OR Expr		{$$=makenode($1,$3,OR,0,DUMMY);	 /*err_arg(1,$$);*/}

		| TRUE				{$$=makenode(NULL,NULL,_Truth,TRUE,DUMMY);} 
		| FALSE				{$$=makenode(NULL,NULL,_Truth,FALSE,DUMMY);}

		| Expr '+' Expr		{$$=makenode($1,$3,'+',0,DUMMY); /*err_arg(1,$$);*/}
		| Expr '-' Expr		{$$=makenode($1,$3,'-',0,DUMMY);/*err_arg(1,$$);*/}
		| Expr '*' Expr		{$$=makenode($1,$3,'*',0,DUMMY); /*err_arg(1,$$);*/}
		| Expr '/' Expr		{$$=makenode($1,$3,'/',0,DUMMY); /*err_arg(1,$$);*/}
		| Expr '%' Expr		{$$=makenode($1,$3,_mod,0,DUMMY);/*err_arg(1,$$);*/}
		| INT 				{$$=makenode(NULL,NULL,INT,$1,DUMMY);}
		| Var   			{$$ = $1;}
		| ID '(' ExpList ')'{$$ = makenode($3,NULL,FUNC,0,$1);}
		| ID '('  	  ')'	{$$ = makenode(NULL,NULL,FUNC,0,$1);}
		;

ExpList : ExpList ',' Expr1  {$$ =makenode($1,$3,_ExpList,0,"ExpList");}
		|	Expr1 			{$$ =makenode(NULL,$1,_ExpList,0,"ExpList");}
		;

Expr1 : Expr 				{$$ = $1;}
		| '&' ID            {$$ = makenode(NULL,NULL,_pointer,0,$2);/*new change*/}
		| '&' ID '['Expr ']'{$$ = makenode($4,NULL,_pointer,0,$2);}
		;

Var		: ID 				{$$=makenode(NULL,NULL,ID,0,$1);}
		| ID '[' Expr ']'	{$$=makenode($3,NULL,ARRAY,0,$1);}
		;

%%

//=========================================================================================================

//====================================================================================

void func_check_list(struct node * nd,struct gnode *temp ){
	if (nd == NULL) return;
	else if (temp != NULL){

		int t = getType(nd->left);
		int typ = temp->type;
		printf("temp->bind = %d , getType = %d\n",typ,t);
		if (typ >= 5) typ = typ -5;
		else if(typ >= 3) typ = typ - 3;
		if(typ != t) {getline();printf("Error in arguments of func\n");exit(1);}
		func_check_list(nd->right,temp->next);
	} 
	//else{getline();printf("Mismatch in number of args in func\n");exit(1);}
	return;
}

//temp1 is global node pointer associated with checkargs func only
struct gnode * temp1;
//checks for arguments of func in func definitions 
//----------  not declarations in global symbol table 
int check_args(struct node *nd,int i){
	
	if(nd == NULL ) return  1;
	switch(nd->flag){

		case _ArgList : {int t= check_args(nd->right,i) ;int u= check_args(nd->left,i); return t&&u;}
		case GINT : {int t = check_args(nd->left,0); return t;}
		case GBOOL: {int t = check_args(nd->left,1);return  t;}

		case _List : {int t1 = 0;//strcmp(nd->right->varname,temp1->name);

						if(t1!=0 || (temp1->type != i && temp1->type -5 != i)) {
							printf("mismatch in arguments of func (%s %d - %s %d)\n",temp1->name,temp1->type,nd->right->varname,i);
							return 0;
						}
						if(temp1->next) temp1 = temp1->next;
						int t= check_args(nd->left,i); return t;
					}
	}

}

int func_check1(int return_type,char *name,struct node *nd){

	//printf("Asked for checking func %s and arg at %d\n",name,nd->flag);
	struct gnode *temp;
	temp = fetch(head,name);

	int flag =1; //init every thing's okay 

	//if func not present
	if(!temp){ getline();printf("undeclared function defined");flag =0;exit(1);}

	//else
	//check return type of func
	//printf("%d && %d\n",temp->type,return_type);
	if(temp->type-3 != return_type) {getline();printf("return type error\n");flag =0;exit(1);/*error(6)*/}


	//temp1 is global node pointer associated with checkargs func only
	temp1 = temp->args;

	//function name and return type  are okay
	//check the arguments

	int t  = check_args(nd , -1);
	if( t == 0 || flag!=1) return -2;

	else return -1; //good
}


//NOTE : ADD func local table at codegen part 

//========================================================================================================
//helper for list_checker
int getType(struct node * nd){
	switch(nd->flag){
		case _pointer : 
		case ID : 	{
						struct gnode * temp = fetch(local_head,nd->varname);
						if(temp == NULL) temp = fetch(head,nd->varname);
						if(temp == NULL) {getline();printf("Undeclared var\n");exit(1);}
						int typ = temp->type;
						if(temp->type ==5 || temp->type ==6) typ = typ -5;
						return typ;
					}
		case ARRAY : {
						struct gnode * temp = fetch(head,nd->varname);
						if(temp == NULL) {getline();printf("Undeclared array\n");exit(1);}
						return temp->type; 
					}	
		case '<' :case '>' :case GE :case LE :case NE :case EQEQ:case NOT :
		case AND :case OR :case _Truth :	return 1;
		
		case '+':case '-':case '%':case '*':case INT : case '/':	return 0;
		
		case FUNC : {struct gnode * temp = fetch(head,nd->varname);if(temp) return temp->type-3;}
		//this is cause : func args cannot have funcs
	}
}

//temp2 is global node pointer associated with list_checker func only
struct gnode * temp2;
//helpewr function for func_check2
int list_checker(struct node * nd){
	if (nd == NULL) return -1;
	if(nd->right){
		int t1 = 0;//strcmp(nd->right->varname,temp2->name);
		//or coulg only check  the type
		int typ = getType(nd->right);
		//printf("name : %d at %s\n",nd->flag, nd->right->varname);
		//printf("typo is here %d expected %d\n",typ,temp2->type );
		if(t1!=0 || (temp2->type != typ && temp2->type -5 !=typ )) {
			getline();
			printf("mismatch in arguments of func (%s %d - %s %d)\n",temp1->name,temp2->type,nd->right->varname,typ);
			exit(1);
		}
		if(temp2->next) temp2 = temp2->next;		
		int t= list_checker(nd->left); 		
		return t;
	}
	else printf("something smells\n");
}


//function  In expressions
int func_check2(struct node * nd){

	struct gnode *temp;
	temp = fetch(head,nd->varname);

	if(!temp) {getline();printf("undeclared function used\n");exit(1);/*error(7);*/}
	else if(temp->args != NULL && nd->left == NULL) {getline();printf("Arguments mismatch\n");exit(1);}
	else if(temp->args == NULL && nd->left != NULL) {getline();printf("Arguments mismatch\n");exit(1);}
	else if(temp->args == NULL && nd->left == NULL) return temp->type-3;
	//main part
	//temp2 is global node pointer associated with list_checker func only
	if(temp->args != NULL && nd->left != NULL){
		temp2 = temp->args;		
		list_checker(nd->left);
	}
	return temp->type-3;
}
//=============================================================================================

void ret_check(int i,struct node * nd){
	int t = type_check2(nd->left);
	if(t != i ) {getline();printf("return type error\n");exit(1);/*error(6)*/}
	return ;
}
//==========================================================================================

//version 2   typecheck need to be improved
//returns : -1 okay ,-2 not ok , type of the var(0,1)
//1 for bool ;  0 for int int 
int type_check2(struct node * nd ){ // -1 is good sign , -2 is bad
	if(nd== NULL) {return -1;}

	switch(nd->flag){

		case WRITE:	{int l = type_check2(nd->left);if (l == 0 ) return -1;error(3);}
		case READ : {int l = type_check2(nd->left);return -1;error(4);}
		case '='  :	{int l = type_check2(nd->left); int r = type_check2(nd->right);if(l==r) return -1;error(5);}
		case WHILE: {int l = type_check2(nd->left); if (l == 1) return -1;error(4);}
		case IF   :	{int l = type_check2(nd->left);if(l==1) return -1;error(4);}
		
		case '<'  : case '>'  : case EQEQ :case NE   :case LE   :case GE   : 
		{int l = type_check2(nd->left);int r = type_check2(nd->right);if(l==0 && r==0) return 1;error(3);}

		case '+'  : case '-'  : case '*'  :case _mod :case '/'  : 
		{int l = type_check2(nd->left); int r = type_check2(nd->right);
						if(l==0 && r==0) return 0;error(3);}
		case INT  : return 0;
		
		case ARRAY : case ID  : 
		{/*ADD : arr[exp] checker for exp not to be bool*/
			if(nd->left){
				//printf("HERE \n");
				int t = type_check2(nd->left);
				if(t != 0) {getline();printf("Error at array exp\n");exit(1);}
			}
			struct gnode * temp; temp = fetch(local_head,nd->varname);//printf("%d\n",temp); 
					//if (temp == NULL) temp = fetch_args(func,nd->varname);
					if(temp == NULL) temp = fetch(head,nd->varname);
					if(temp == NULL) {getline();printf("no such var detected\n");exit(1);}
					int m = temp->type ;
					if(m == 5 || m == 6) m = m-5; 
					  return m;		
		}	
		case _Truth: {if(nd->val == TRUE || nd->val == 	FALSE) return 1;error(4);}

		case AND :case OR  :case NOT : 
		{int l = type_check2(nd->left);int r=1; if(nd->right){ r = type_check2(nd->right);} 
					if(l==1 && r ==1) return 1; error(4);}

		case FUNC : {return func_check2(nd);/*func check in statements like [ a= foo(); ]*/}
		
	}

}

void err_arg(int flag,struct node * nd){
	if(type_check2(nd)!=flag ){
		getline();
		printf("Error in exp in arguments\n");
		exit(1);
	}
	return;
}
//CODE GENERATION PART=================================================================



//--------------------------------------------

//Episode : INSTALL

//=============================================
void flush_local(){
	//free memoey of past local_head
	/*
	if(local_head && local_head->next){
		struct gnode * delnode = local_head->next;	//safe to do like this -- good prctice
		struct gnode * helper;
		
		while(delnode){
			helper = delnode ;
			delnode = delnode->next;

			//free(helper->name); 					//so we can free only pointers
			//free(helper->size);
			//free(helper->bind);
			free(helper->next);
			free(helper->args);
			
		}
	}
	else if(local_head && local_head->next== NULL){
		free(local_head->next);
		free(local_head->args);
	}
	*/
	local_head = NULL;
	//return;
}

//INITIALIZERS-----------------------------------------------------------------
void local_bind_count_init(){
	agcount = 1;
	return;
}
int get_local_bind_count(){
	agcount+=1;
	return agcount-1;
}

//[BP - 3] for arguments in run stack
int nastyCount=-3;	//warning : initialize everytime to -3 do nort forget stupid

void arg_bind_count_init(){
	nastyCount = -3;
}

int get_arg_bind_count(){	//sophistication can be addded by increasing param
	nastyCount-=1;
	return nastyCount+1;
}
//-------------------------------------------------------------------------------

void foo(int i, char * _name){
	struct gnode * temp;
	temp = (struct gnode *) malloc(sizeof(struct gnode)) ;
	temp->name = _name;
	temp->type = i;
	temp->bind = get_arg_bind_count();
	//nastyCount--;
	temp->args = NULL;

	temp->next = local_head;
	local_head = temp;


}


void install_args_to_locals(int i,struct node * nd){
	if (nd == NULL) return;
	//printf("sam is hwrw\n");
	switch(nd->flag){
		case _ArgList:{install_args_to_locals(i,nd->left);install_args_to_locals(i,nd->right);break;}
		case GINT :   {install_args_to_locals(0,nd->left);break;}
		case GBOOL:   {install_args_to_locals(1,nd->left);break;}
		case _List :  {install_args_to_locals(i,nd->left);
						if(nd->right->flag == _pointer) i = i+POINT;
						//printf("I like iceceram %d \n",i);
						foo(i,nd->right->varname);break;}
	}
	return;
}

// i rep's type : important logic for pointers
//this func is for tye checking of a function
void install_local_var(struct node *nd,int i){

	struct gnode * t = fetch(local_head , nd->varname);
	if (t != NULL) {getline();printf("redeclared var in local \n");exit(1);}
 
	struct gnode * temp;
	temp = (struct gnode *) malloc(sizeof(struct gnode ));

	//NEED to change the BIND here
	temp->name = nd->varname;
	temp->type = i;
	temp->args = NULL;
	//initial binding of locals 
	temp->bind = -100;

	//install locals in local table
	temp->next = local_head;
	local_head = temp;

}


//at global sym table func declarations

//	t  : func_arg_head 		count for numbering args 	i is return type

void install_args_to_func_in_global(struct gnode *t,struct node *nd,int i,int count){ 
	if(nd == NULL) return;
	switch(nd->flag){
		case _ArgList: {install_args_to_func_in_global(t,nd->left,i,count);install_args_to_func_in_global(t,nd->right,i,count);break;}
		case GINT : {install_args_to_func_in_global(t,nd->left,0,count);break;}
		case GBOOL: {install_args_to_func_in_global(t,nd->left,1,count);break;}
		case _List :{install_args_to_func_in_global(t,nd->left,i,count+1);
						struct gnode *temp;


						temp = (struct gnode *)malloc(sizeof(struct gnode ));
						temp->name = nd->right->varname;
						//printf("sai %d\n",nd->right->flag);
						//NOTICE for pointer: type = 5,6 for int ,bool pointers
						if(nd->right->flag == _pointer) {i = i+POINT;}
						temp->type = i;
						temp->args = NULL;
						temp->bind = count;
						temp->next = t->args;
						t->args = temp;
						break;
					}
	}
	return;
}

//allcating space in memory of target machine
//suggestion : Add error msg for redeclarations;
//NOTE : I think func arg can be removed since local sym table is being crearted

//flag indicates whether to local_head or global
void evalDecl(int Flag,struct node *nd,int i,char * func){	// i for type filling in table
	if(nd == NULL ) {
		//for relative adddressing of local variable
		// initialisig after every time
		return;
	}
	switch(nd->flag){
		//case _GDefList: evalDecl(nd->left,i);evalDecl(nd->right,i); break;
		//case GINT: 		evalDecl(nd->left,0); break;
		//case GBOOL: 	evalDecl(nd->left,1); break;
		case _GIdList: 	evalDecl(Flag,nd->left,i,func);

						if(nd->right->flag==ID) {
							//printf("same %s\n",nd->right->varname);
							gentry(nd->right->varname,i,1,LocNo);//1 rep's size
							LocNo++;
						}
						else if(nd->right->flag == ARRAY){
							//printf("same %s\n",nd->right->varname);
							int size = nd->right->left->val;
							gentry(nd->right->varname,i,size,LocNo);
							LocNo += size;							

						}
						//pointer mark
						else if(nd->right->flag == FUNC ){
							//printf("same %s\n",nd->right->varname);
							struct gnode * temp;
							//gnode for function in global symbol table
							temp =(struct gnode *) malloc(sizeof(struct gnode));
							
							temp->name = nd->right->varname;
							int func_type;
							if(i==0) func_type=3;
							else if(i == 1) func_type=4;

							//printf("func name %s(%d)\n",nd->right->varname,);

							temp->type = func_type;
							temp->args = NULL;
							temp->flabel = Label; Label++; 

							//head is here now use your head
							temp->next =head;
							head = temp;
							install_args_to_func_in_global(temp,nd->right->left,i,0);	
							//i means nothing but useful in "inst_args_func_glob"
							//nd->r->l : arg starts	

						}break;

		case _LDefList: evalDecl(Flag,nd->left,i,func);evalDecl(Flag,nd->right,i,func);break;
		case GINT 	: evalDecl(Flag,nd->left,0,func);break;
		case GBOOL	: evalDecl(Flag,nd->left,1,func);break;

		case _LIdList: 	evalDecl(Flag,nd->left,i,func);
						//struct gnode *temp ;
						//temp = fetch(head,func);
						//print_table();
						//printf("type : %d ,i = %d\n",temp->type,i);
						//if(!temp) {printf("Function undeclared\n");exit(1);}
						
						//if(temp->type-3 !=  i) {printf("function of different typecheck\n");exit(1);}
						install_local_var(nd->right,i);

						break;	
	}
}

//=======================================----------------------------------======

//code gen helpers=============================================================
void printRegStack(){	//needn't touch
	return;
	regCallCount++;

	printf("( %d )regStack : ",regCallCount);
	int i;
	for( i=0;i<8;i++){
		if(regStack[i]==-1 ) break;
		printf("%d ",regStack[i]);
	}
	printf("\n");

}

void freeReg(int r,struct node * nd){	
//if reg r at top of reg stack the remove else return error
	//if(r==0) {printRegStack();return;}
	if(r < 	0) {getline();printf("cannot free get whe all are free \n");exit(1);}
	if (RegNo < 0) {getline(); printf("attempt to free reg at -1\n");exit(1);}
	if(r==RegNo)
	{	RegNo--;regStack[RegNo+1]=-1;
		printRegStack();}
	else{
		printf("%d cannot happen reg(%d) - %d",lineno,r,RegNo);
		if(nd) printf("at %d\n",nd->flag);
		if(nd->left) printf(": l(%d)  ",nd->left->flag);
		if(nd->right) printf(": r(%d) ",nd->right->flag);printf("\n");
	}
}	

//allocates a new register by increasing a global count
int getReg(){
	RegNo++;
	if(RegNo >7) {
		getline();
		printf("Exeeded register usage\n");
		exit(1);
	}
	regStack[RegNo] =RegNo;
	printRegStack(); 
	int r = RegNo;
	return r;
}

//gets loc of a var in a reg
int getLoc(char * varname){	

	struct gnode * temp;
	temp = fetch(local_head,varname);
	if(temp) {
		int loc = temp->bind;							//fetch in local
		int r1 = getReg();
		int r2 = getReg();
		fprintf(fp,"MOV R%d,BP\n",r1);
		fprintf(fp,"MOV R%d,%d\n",r2,loc);			
		fprintf(fp,"ADD R%d,R%d\n",r1,r2);
		freeReg(r2,NULL);
		return r1;
	}
	
	else temp = fetch(head,varname);					//fetch in  global tab

	if(temp){
		int loc = temp->bind;
		int r = getReg();

		fprintf(fp, "MOV R%d,%d\n",r,loc);
		return r;
	}
	if(temp == NULL) {getline();printf("Local symbol table -- biscuit\n");exit(1);}
	//printf("saikumar");
}


int isLocGlobal(int i){
	if(i>=200000) return 1;
	else return 0;
}

//returns (array base addr + location num in expr) in a reg
int getLocArray(struct node * nd){
	
	int r = CodeGen(nd->left);
	int r1 = getLoc(nd->varname);
	int foo = fprintf(fp,"ADD R%d,R%d\n",r,r1);	//add r + r1	
	freeReg(r1 , nd);
	return r; //contains final location of array element
}

//func used in codegen() 
int op(struct node* nd , int flag){

	int r1 = CodeGen(nd->left);	//increment for r1 will be done in rec part			
	int r2 = CodeGen(nd->right);

	switch(flag){
		case 1:{int foo =  fprintf(fp,"ADD R%d,R%d\n",r1,r2);break;}
		case 2:{int foo =  fprintf(fp,"SUB R%d,R%d\n",r1,r2);break;}
		case 3:{int foo =  fprintf(fp,"MUL R%d,R%d\n",r1,r2);break;}
		case 4:{int foo =  fprintf(fp,"DIV R%d,R%d\n",r1,r2);break;}

		case 5:{int foo =  fprintf(fp,"LT R%d,R%d\n",r1,r2);break;}
		case 6:{int foo =  fprintf(fp,"GT R%d,R%d\n",r1,r2);break;}
		case 7:{int foo =  fprintf(fp,"EQ R%d,R%d\n",r1,r2);break;}
		case 8:{int foo =  fprintf(fp,"LE R%d,R%d\n",r1,r2);break;}
		case 9:{int foo =  fprintf(fp,"GE R%d,R%d\n",r1,r2);break;}
		case 10:{int foo =  fprintf(fp,"NE R%d,R%d\n",r1,r2);break;}
		case 11:{int foo =  fprintf(fp,"MOD R%d,R%d\n",r1,r2);break;}
	}

	freeReg(r2 , nd);

	return r1;
}

//CODEGEN===============================================================
//generates machine code for SIM
//returns regno to be used at an instance


void foo2(int i, char * _name,int _bind){
	struct gnode * temp;
	temp = (struct gnode *) malloc(sizeof(struct gnode)) ;
	temp->name = _name;
	temp->type = i;
	temp->args = NULL;
	temp->bind = _bind;

	temp->next = local_head;
	local_head = temp;
}

//add locals to local table and binds them to mem relative to bp
void bind_locals_to_mem(int i,struct node * nd){
	int bind;
	if (nd == NULL) return;
	switch(nd->flag){
		case _LDefList : {bind_locals_to_mem(i,nd->left);bind_locals_to_mem(i,nd->right);break;}
		case GINT : {bind_locals_to_mem(0,nd->left);break;}
		case GBOOL: {bind_locals_to_mem(1,nd->left);break;}
		case _LIdList : {
							bind_locals_to_mem(i,nd->left);
							struct gnode * temp = fetch(local_head,nd->right->varname);
							if(temp == NULL)
							bind = get_local_bind_count();

							foo2(i,nd->right->varname,bind);	//main part
							break;
						}
	}
	return ;
}
//_____________________________________________
//helper to func_code_gen
void alloc_mem_for_func_locals(struct node * nd){
	if(local_head){
		int m = local_head->bind; printf("val is impoertantianno %d\n", m);
		///*
		int r = getReg();
		fprintf(fp,"MOV R%d, 0\n",r);	//for init-ing all locals to 0
		print_locals();
		
		
		int  i=0;
		while(i<m){			//CHANGE : this can be writtren as increasing sp only
			fprintf(fp,"PUSH R%d\n",r);
			i=i+1;
		}
		
		freeReg(r,nd);
		//*/
		/*
		//  SP  =  SP  +  m ;
		int r = getReg();
		int r1 = getReg();
		fprintf(fp, "MOV R%d,%d\n",r,m);
		fprintf(fp, "MOV R%d,SP\n",r1);
		fprintf(fp, "ADD R%d,R%d\n",r,r1);
		fprintf(fp,"MOV SP,R%d\n",r);
		freeReg(r1,nd);
		freeReg(r,nd);
		*/

		//printf("say hi to me now\n");
	}
}
//ADD : label to func  in gsymtab

void func_code_gen(int i,struct node * nd){
	if (nd == NULL) return ;
	switch(nd->flag){
		//case _Fdeflist : {func_code_gen(i,nd->left);func_code_gen(i,nd->right);break;}
		case _Fdef : {
						//make the local table then generate the code

						flush_local();
						printf("------Visting : %s\n",nd->varname);

						fprintf(fp,"L%d:\n",nd->val);
						//if(nd->flag != _main)
						fprintf(fp,"PUSH BP\n");
						fprintf(fp,"MOV BP,SP\n");
						local_bind_count_init();
						arg_bind_count_init();
						//agcount = 1;				//for local vars
						//nastyCount = -3;  		//for the sake of arguments -- do you get it?
						install_args_to_locals(-1,nd->right->left);
						bind_locals_to_mem(-1,nd->right->right);
						//printf("safty check ");print_locals();
						//by looking the first (last entered var in local sym tab inc the sp i.e push a reg)
						alloc_mem_for_func_locals(nd);		//stack manip
						int r = CodeGen(nd->left);

						//freeReg(r,nd);
						flush_local();
						break;	
						}
	}
	return;
}

int getFuncLabel(char * name){
	struct gnode * temp = fetch(head, name);
	return temp->flabel;
}


int CodeGen(struct node *nd){
	if(nd==NULL) return -1;
	switch(nd->flag){
		case _body : {CodeGen(nd->left);CodeGen(nd->right);break;}

		case _Truth : 
					{ int value = 0 ; if(nd->val == TRUE) value =1;
					  
					  int r = getReg();
					  
					  int foo = fprintf(fp,"MOV R%d,%d\n",r,value);
					  
					  return r; 
					}
		case _pointer:{
						int r = get_pointer_addr(nd);
						return r;
					}
		case INT:	{int r = getReg();

					int foo = fprintf(fp,"MOV R%d,%d\n",r,nd->val);

					return r;

					break;} 

		//club ID and Array
		case ID :	{int r = getReg();
					
					int r1 = getLoc(nd->varname);

					int foo = fprintf(fp,"MOV R%d,[R%d]\n",r,r1);

					struct  gnode * temp  = fetch(local_head,nd->varname);
					if(temp)

					if(temp->type == 5 || temp->type == 6){

						fprintf(fp,"MOV R%d,[R%d]\n",r,r);

					} 

					freeReg(r1,nd);
					
					return r;
					
					break;}

		case ARRAY :{int r = getReg();
					
					int r1 = getLocArray(nd);	// in a register

					int foo = fprintf(fp,"MOV R%d,[R%d]\n",r,r1);//mov r [r1] 	

					freeReg(r1 , nd);

					return r;
					
					break;}
		
		case _StmtList:{CodeGen(nd->left);CodeGen(nd->right);break;}

		case '+' :	{int reg = op(nd,1); return reg;break;}
		case '-' :	{int reg = op(nd,2); return reg;break;}
		case '*' :	{int reg = op(nd,3); return reg;break;}
		case '/' :	{int reg = op(nd,4); return reg;break;}
		case '<' :	{int reg = op(nd,5); return reg;break;}
		case '>' :	{int reg = op(nd,6); return reg;break;}
		case EQEQ :	{int reg = op(nd,7); return reg;break;}
		case  LE :	{int reg = op(nd,8); return reg;break;}
		case  GE :	{int reg = op(nd,9); return reg;break;}
		case  NE :	{int reg = op(nd,10); return reg;break;}
		case _mod :	{int reg = op(nd,11); return reg;break;}

		
		case '=' :	//one reg for returning remaining canbe disposed off
					{int r = CodeGen(nd->right);				//right part of =
					//fprintf(fp,"OUT R%d\n",r);
					//printf("good  ");printRegStack();
					if(nd->left->flag == ID){
						
						int r1 = getLoc(nd->left->varname);
						//printf("Bad %d\n",r1);

						

						struct gnode* temp  = fetch(local_head,nd->left->varname);

						if(temp)
						if(temp->type == 5 || temp->type == 6){

							fprintf(fp,"MOV R%d,[R%d]\n",r1,r1);
							
						}

						fprintf(fp,"MOV [R%d], R%d\n",r1,r);

						freeReg(r1,nd);
						//fprintf(fp,"num = %d\n",r1);
						//fprintf(fp,"Error123\n");
						freeReg(r,nd);

						return -1;
					}

					else if(nd->left->flag == ARRAY){		//left part of =

						int r1 = getLocArray(nd->left);

						int foo =  fprintf(fp,"MOV [R%d],R%d\n",r1,r);

						freeReg(r1,nd);

						freeReg(r,nd);

						return -1;						

					}
					
					break;}

		

		case WRITE : //printing out of register
					{
						int  r = CodeGen(nd->left);

						//printf("sam is here\n");

						fprintf(fp,"OUT R%d\n",r);

						freeReg(r,nd);

						return -1;

						break;}

		case READ :	{//load to register then load to memorand

					int r = getReg();

					if(nd->left->flag == ID){

						int foo = fprintf(fp,"IN R%d\n",r);

						int r1 = getLoc(nd->left->varname);

						struct gnode* temp  = fetch(local_head,nd->left->varname);

						if(temp) {

							if(temp->type == 5 || temp->type == 6){

								fprintf(fp,"MOV R%d,[R%d]\n",r1,r1);
							
							}
						}
						
						foo = fprintf(fp,"MOV [R%d],R%d\n",r1,r);

						freeReg(r1,nd);

						freeReg(r,nd);

						return -1;

					}
					else if(nd->left->flag == ARRAY) {

						int foo = fprintf(fp,"IN R%d\n",r);

						int r1 = getLocArray(nd->left);

						foo = fprintf(fp,"MOV [R%d],R%d\n",r1,r);

						freeReg(r1,nd);

						freeReg(r,nd);

						return -1;

					}

					break;}

		case IF:{
					int r  = CodeGen(nd->left);
					int l;	//reserved for else part
					int l1 = Label;
					Label++;
					int foo = fprintf(fp,"JZ R%d,L%d\n",r,l1);
					freeReg(r,nd);

					if(nd->right->flag == ELSE)	{
						foo = CodeGen(nd->right->left);
						l = Label;
						Label++;
						fprintf(fp, "JMP L%d\n",l);
					}

					else foo = CodeGen(nd->right);
					
					foo = fprintf(fp,"L%d: ",l1);

					if(nd->right->flag == ELSE)	{
						foo = CodeGen(nd->right->right);
						fprintf(fp, "L%d:\n",l );
					}

					

					return -1;
				}


		case AND :{
					int r1 = CodeGen(nd->left);

					int r2 = CodeGen(nd->right);
					
					int foo = fprintf(fp,"MUL R%d,R%d\n",r1,r2);

					freeReg(r2,nd);

					return r1;

					break;

					}

		case OR :{
					int r1 = CodeGen(nd->left);

					int r2 = CodeGen(nd->right);
					
					int r3 = getReg();

					int foo = fprintf(fp,"MOV R%d,R%d\n",r3,r1);

					foo = fprintf(fp,"ADD R%d,R%d\n",r1,r2);

					foo = fprintf(fp,"MUL R%d,R%d\n",r3,r2);

					foo = fprintf(fp,"SUB R%d,R%d\n",r1,r3);

					freeReg(r3,nd);

					freeReg(r2,nd);

					return r1;

					break;

					}

		case NOT :{
					int r = CodeGen(nd->left);

					int r1 = getReg();

					int foo = fprintf(fp,"MOV R%d,1\n",r1);

					foo = fprintf(fp,"LT R%d,R%d\n",r,r1);

					freeReg(r1,nd);

					return r;

					break;

					}

		case WHILE :{
						//fprintf(fp, "WHILE start------\n");
						int l1 = Label;
						Label++;

						int foo = fprintf(fp,"L%d:",l1);						

						int r = CodeGen(nd->left);
						
						int l2 = Label;
						Label++;
						foo = fprintf(fp,"JZ R%d,L%d\n",r,l2);

						freeReg(r,nd);

						foo= CodeGen(nd->right);

						foo = fprintf(fp,"JMP L%d\n",l1);

						foo = fprintf(fp,"L%d:",l2);

						//fprintf(fp, "WHILE end--------\n" );

						return -1;

						break;

					}

		case FUNC : {	//ADD : improve this point geta reg free it 
						//		 in this process you will get the max reg in use
						printf("Function call %s\n",nd->varname);

						/*

						struct gnode* temp = local_head;
						while(temp && temp->bind >=-2) temp = temp->next; 
						func_check_list(nd->left,temp);

						*/

						int r = getReg();
						freeReg(r,nd);
						printf("last free reg : %d\n",r-1);
						int i = 0;
						while(i<r){ 
							fprintf(fp, "PUSH R%d\n",i );
							//freeReg(i,nd);
							i=i+1;
						}
						
						//ADD : FREE THE REGs
						
						push_list(nd->left);

						r = getReg();
						fprintf(fp, "PUSH R%d\n", r); //return add
						freeReg(r,nd);
						int lab = getFuncLabel(nd->varname);

						//CALL the function
						fprintf(fp,"CALL L%d\n",lab);

						r = getReg();
						fprintf(fp,"POP R%d\n",r);	//	r == return val i guess
						
						pop_list(nd->left);
						
						//something's fishy here : how to store return value
						/*
						i =0 ;
						while(i<r){
							int t = getReg();
							i = i+1;
						}
						*/
						i=r-1;
						while(i>=0){
							fprintf(fp,"POP R%d\n",i);
							i--;
						}
						return r;
					}

		case RET : {	

						int r = CodeGen(nd->left);
						int r1 = getReg();
						int  r2 = getReg();
						fprintf(fp,"MOV R%d,2\n",r2);
						fprintf(fp,"MOV R%d,BP\n",r1);
						fprintf(fp,"SUB R%d,R%d\n",r1,r2);
						fprintf(fp,"MOV [R%d],R%d\n",r1,r);
						//fprintf(fp, "MOV [BP - 2], R%d\n",r );
						freeReg(r2,nd);
						freeReg(r1,nd);
						freeReg(r,nd);
						fprintf(fp, "MOV SP,BP\n");
						fprintf(fp,"POP BP\n");
						fprintf(fp,"RET\n");
						printf("End of a function\n");
						return -1;
					}
	}
}

//first arg pushed last
void push_list(struct node * nd){

	if(nd == NULL) return;

	//this sequence is important and arg names must match exactly

	//pusing the value only (change the strat for pointers)
	int r = CodeGen(nd->right);

	fprintf(fp,"PUSH R%d\n",r);

	freeReg(r,nd->right);

	push_list(nd->left);

	return;
}

void pop_list(struct node * nd){
	if (nd == NULL) return;

	pop_list(nd->left);

	int r =getReg();

	fprintf(fp,"POP R%d\n",r);

	freeReg(r,nd->right);

	return ;
}

//Old code need not be looked at

//========================EVAL TREE


/*
//improvement required : use switch and cases to make code pretty
//tree evaluation------------======================================================
int evaltree(struct node* nd,int i){		//infix eval
	//printf("Evaluation\n");
	if (nd == NULL) {	
		return 1;
	}
	//print(nd);/
	if(nd->flag==INT){		//integer
		return nd->val;
	}	

	//check both sides as integer
	if (nd->flag=='+')
		return (evaltree(nd->left,i) + evaltree(nd->right,i));

	else if(nd->flag== '*')
		return (evaltree(nd->left,i) * evaltree(nd->right,i));
	
	else if(nd->flag=='/')
	 	return (evaltree(nd->left,i) / evaltree(nd->right,i));
	
	else if(nd->flag=='-')
	 	{	printf("%d - %d\n",evaltree(nd->left,i) ,evaltree(nd->right,i) );
	 		int dog= (evaltree(nd->left,i) - evaltree(nd->right,i));
	 		printf("dog = %d\n",dog);
	 		return dog;
	 	}

	else if(nd->flag==_mod)
	 	{	printf("%d mod %d\n",evaltree(nd->left,i) ,evaltree(nd->right,i) );
	 		int dog= (evaltree(nd->left,i) % evaltree(nd->right,i));
	 		printf("dog = %d\n",dog);
	 		return dog;
	 	}



	else if(nd->flag=='>'){
		if (evaltree(nd->left,i) > evaltree(nd->right,i)) return TRUE;
	 	else return FALSE;
	}
	else if(nd->flag=='<'){
	 	if (evaltree(nd->left,i) < evaltree(nd->right,i)) return TRUE;
	 	else return FALSE;
	}

	else if(nd->flag==EQEQ){
	 	if (evaltree(nd->left,i) == evaltree(nd->right,i)) return TRUE;
	 	else return FALSE;
	}


	//later added
	else if(nd->flag==NE){
	 	if (evaltree(nd->left,i)!=evaltree(nd->right,i)) return TRUE;
	 	else return FALSE;
	}
	else if(nd->flag==GE){
	 	if (evaltree(nd->left,i)>= evaltree(nd->right,i)) return TRUE;
	 	else return FALSE;
	}
	else if(nd->flag==LE){
	 	if (evaltree(nd->left,i) <= evaltree(nd->right,i)) return TRUE;
	 	else return FALSE;
	}



	//checking for bool (and. or .not . )
	if(nd->flag==AND){
		if (evaltree(nd->left,i) == TRUE  && evaltree(nd->right,i) == TRUE )
			{;return TRUE;}
		else return FALSE;
	}
	else if(nd->flag==OR){
		if (evaltree(nd->left,i) == FALSE  && evaltree(nd->right,i) == FALSE )
		return FALSE;
		else return TRUE;
	}
	else if(nd->flag==NOT){
	 	if (evaltree(nd->left,i) == TRUE )  return FALSE;
		else return TRUE;
	}

	
	else if(nd->flag==_Truth){
		//printf("Asked for %d\n",nd->val);
			return nd->val;
	}


	else if(nd->flag== '='){
		int t=evaltree(nd->right,i);
			//printf("Doggie kruger %d",nd->right->flag);
			//printf("changer  %d\n",t);			
			//printf("found to change : %s\n",nd->left->varname);
		if(nd->left->flag==ID)   set(nd->left->varname,t,0);

		else if(nd->left->flag==ARRAY){
			int place = evaltree(nd->left->left,i);
			set(nd->left->varname,t,place);
		}


	}
	

	else if(nd->flag==_Program){
		evaltree(nd->left,i);
		evaltree(nd->right,i);
	}

	else if(nd->flag==_GDefList){
		evaltree(nd->left,i);
		evaltree(nd->right,i);
	}
	else if(nd->flag==GINT){	//to declaration
		evaltree(nd->left,0);	//important type here

	}
	else if(nd->flag==GBOOL){	//here too----------
		evaltree(nd->left,1);	
	}

	else if(nd->flag==ID){		//getter
		//printf("test@identi : %s\n",need->varname);
		struct gnode * temp;
		temp=fetch(nd->varname);
		int num= *(temp->bind);
		return num;

	}

	else if(nd->flag==ARRAY){
		struct gnode * temp;
		int place=evaltree(nd->left,i);
		temp=fetch(nd->varname);
		int num= *(temp->bind+place);
		return num;
		
	}

	else if(nd->flag==_Varlist){
		evaltree(nd->left,i);
		
		if(nd->right->flag==ID) {
			gentry(nd->right->varname,i,1);
			return 1;
		}
		
		else if(nd->right->flag==ARRAY){
			int size=evaltree(nd->right->left,i);
			gentry(nd->right->varname,i,size);
			return 1;
		}
	}

	else if(nd->flag==INTD){
		evaltree(nd->left,0);				//type =0 for integers
				
	}
	else if(nd->flag==READ){				//alpha : need to check
		
		int temp;	
		printf("Enter a number : ");
		scanf("%d",&temp);

		if(nd->left->flag==ID)
			set(nd->left->varname,temp,0); //set
		else{
			int place = evaltree(nd->left->left,i);
			set(nd->left->varname,temp,place);
		}
		printf("reading done\n");
		
	}

	else if(nd->flag==WRITE){

		printf("printing %d\n",evaltree(nd->left,i));

	}

	else if(nd->flag==IF){	
		
		if (evaltree(nd->left,i)==TRUE) evaltree(nd->right,i);
		else return 1;
	}

	else if(nd->flag==WHILE){

		while(evaltree(nd->left,i) == TRUE){
			evaltree(nd->right,i);
		}

	}

	else if(nd->flag == _StmtList){

		evaltree(nd->left,i);
		evaltree(nd->right,i);

	}

	return 1;
}
*/