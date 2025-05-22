/* Please feel free to modify any content */

/* Definition section */
%{
    #include "compiler_common.h"
    // #define YYDEBUG 1
    // int yydebug = 1;

    extern int yylineno;
    extern int yylex();
    extern FILE *yyin;

    int yylex_destroy ();
    void yyerror (char const *s)
    {
        printf("error:%d: %s\n", yylineno, s);
    }

    /* Symbol table function - you can add new functions if needed. */
    // Global variable to track the current scope level
    static int current_scope_level = 0;
    // To store the line number of the 'main' function for the final symbol table dump
    static int main_func_lineno = 0;

    static void create_sym_table();
    static void insert_sym_entry(const char* name, int addr, int scope_level, int lineno);
    static void dump_sym_table(int scope_level);
    extern int lookup_addr(const char *name);
    extern char *lookup_type(const char *name);

    /* Global variables */
    bool HAS_ERROR = false;
    static int next_addr = 0;

    /* Symbol table storage */
    #define MAX_SYM 100
    static char* sym_names[MAX_SYM];
    static char* sym_types[MAX_SYM];
    static char* sym_funcsig[MAX_SYM];
    static int sym_addrs[MAX_SYM];
    static int sym_scopes[MAX_SYM];
    static int sym_linenos[MAX_SYM];
    static int sym_mut[MAX_SYM]; // Added for mutability
    static int sym_count = 0;
%}

%error-verbose

/* Use variable or self-defined structure to represent
 * nonterminal and token type
 *  - you can add new fields if needed.
 */
%union {
    int i_val;
    float f_val;
    char *s_val;
    /* ... */
}
%type <s_val> Expr

/* Token without return */
%token LET MUT NEWLINE
%token INT FLOAT BOOL STR
%token TRUE FALSE
%token GEQ LEQ EQL NEQ LOR LAND
%token ADD_ASSIGN SUB_ASSIGN MUL_ASSIGN DIV_ASSIGN REM_ASSIGN
%token IF ELSE FOR WHILE LOOP
%token PRINT PRINTLN
%token FUNC RETURN BREAK
%token ARROW AS IN DOTDOT RSHIFT LSHIFT

%left LOR
%left LAND
%left '>' '<' GEQ LEQ EQL NEQ
%left '+' '-'
%left '*' '/' '%'
%right '!' UMINUS

/* Token with return, which need to sepcify type */
%token <i_val> INT_LIT
%token <f_val> FLOAT_LIT
%token <s_val> STRING_LIT 
%token <s_val> IDENT 
%token '"'           

/* Nonterminal with return, which need to sepcify type */
/* %type <s_val> Type */

/* Yacc will start at this nonterminal */
%start Program

/* Grammar section */
%%

Program
    : GlobalStatementList
      { dump_sym_table(0); /* Dump global symbol table at the end */ }
;

GlobalStatementList 
    : GlobalStatementList GlobalStatement
    | GlobalStatement
;

GlobalStatement
    : FunctionDeclStmt
    | NEWLINE
;

FunctionDeclStmt
    : FUNC IDENT '(' ')' { 
        printf("func: %s\n", $2);
        if (strcmp($2, "main") == 0) {
            main_func_lineno = yylineno;
        }
        insert_sym_entry($2, -1, 0, yylineno);
        sym_names[sym_count] = strdup($2);
        sym_addrs[sym_count] = -1;
        sym_scopes[sym_count] = 0;
        sym_linenos[sym_count] = yylineno;
        sym_types[sym_count] = "func";
        sym_funcsig[sym_count] = "(V)V";
        sym_count++;
        current_scope_level++;   
        next_addr = 0;          
        create_sym_table();      
    } Block {
        dump_sym_table(current_scope_level); 
        current_scope_level--;               
    }
;

Block
    : '{' StmtList '}'
;

StmtList
    : StmtList Stmt
    | Stmt
;

Stmt
    : LET IDENT ':' INT '=' Expr ';' {
        insert_sym_entry($2, next_addr, current_scope_level, yylineno);
        sym_names[sym_count] = strdup($2);
        sym_addrs[sym_count] = next_addr;
        sym_scopes[sym_count] = current_scope_level;
        sym_linenos[sym_count] = yylineno;
        sym_types[sym_count] = "i32"; // Corrected type
        sym_mut[sym_count] = 0;     // Set mutability
        sym_funcsig[sym_count] = "-";
        sym_count++;
        next_addr++;
    }
    | LET IDENT ':' FLOAT '=' Expr ';' {
        insert_sym_entry($2, next_addr, current_scope_level, yylineno);
        sym_names[sym_count] = strdup($2);
        sym_addrs[sym_count] = next_addr;
        sym_scopes[sym_count] = current_scope_level;
        sym_linenos[sym_count] = yylineno;
        sym_types[sym_count] = "f32"; // Corrected type
        sym_mut[sym_count] = 0;     // Set mutability
        sym_funcsig[sym_count] = "-";
        sym_count++;
        next_addr++;
    }
    | LET IDENT ':' BOOL '=' Expr ';' {
        insert_sym_entry($2, next_addr, current_scope_level, yylineno);
        sym_names[sym_count] = strdup($2);
        sym_addrs[sym_count] = next_addr;
        sym_scopes[sym_count] = current_scope_level;
        sym_linenos[sym_count] = yylineno;
        sym_types[sym_count] = "bool";
        sym_mut[sym_count] = 0;     // Set mutability
        sym_funcsig[sym_count] = "-";
        sym_count++;
        next_addr++;
    }
    | LET IDENT ':' STR '=' Expr ';' {
        insert_sym_entry($2, next_addr, current_scope_level, yylineno);
        sym_names[sym_count] = strdup($2);
        sym_addrs[sym_count] = next_addr;
        sym_scopes[sym_count] = current_scope_level;
        sym_linenos[sym_count] = yylineno;
        sym_types[sym_count] = "str";
        sym_mut[sym_count] = 0;     // Set mutability
        sym_funcsig[sym_count] = "-";
        sym_count++;
        next_addr++;
    }
    | LET IDENT ':' '&' STR '=' Expr ';' {
        insert_sym_entry($2, next_addr, current_scope_level, yylineno);
        sym_names[sym_count] = strdup($2);
        sym_addrs[sym_count] = next_addr;
        sym_scopes[sym_count] = current_scope_level;
        sym_linenos[sym_count] = yylineno;
        sym_types[sym_count] = "str";
        sym_mut[sym_count] = 0;     // Set mutability
        sym_funcsig[sym_count] = "-";
        sym_count++;
        next_addr++;
    }
    | LET MUT IDENT ':' INT '=' Expr ';' {
        insert_sym_entry($3, next_addr, current_scope_level, yylineno);
        sym_names[sym_count] = strdup($3);
        sym_addrs[sym_count] = next_addr;
        sym_scopes[sym_count] = current_scope_level;
        sym_linenos[sym_count] = yylineno;
        sym_types[sym_count] = "i32"; // Corrected type
        sym_mut[sym_count] = 1;     // Set mutability
        sym_funcsig[sym_count] = "-";
        sym_count++;
        next_addr++;
    }
    | LET MUT IDENT ':' FLOAT '=' Expr ';' {
        insert_sym_entry($3, next_addr, current_scope_level, yylineno);
        sym_names[sym_count] = strdup($3);
        sym_addrs[sym_count] = next_addr;
        sym_scopes[sym_count] = current_scope_level;
        sym_linenos[sym_count] = yylineno;
        sym_types[sym_count] = "f32"; // Corrected type
        sym_mut[sym_count] = 1;     // Set mutability
        sym_funcsig[sym_count] = "-";
        sym_count++;
        next_addr++;
    }
    | LET MUT IDENT ':' BOOL '=' Expr ';' {
        insert_sym_entry($3, next_addr, current_scope_level, yylineno);
        sym_names[sym_count] = strdup($3);
        sym_addrs[sym_count] = next_addr;
        sym_scopes[sym_count] = current_scope_level;
        sym_linenos[sym_count] = yylineno;
        sym_types[sym_count] = "bool";
        sym_mut[sym_count] = 1;     // Set mutability
        sym_funcsig[sym_count] = "-";
        sym_count++;
        next_addr++;
    }
    | LET MUT IDENT ':' STR '=' Expr ';' {
        insert_sym_entry($3, next_addr, current_scope_level, yylineno);
        sym_names[sym_count] = strdup($3);
        sym_addrs[sym_count] = next_addr;
        sym_scopes[sym_count] = current_scope_level;
        sym_linenos[sym_count] = yylineno;
        sym_types[sym_count] = "str";
        sym_mut[sym_count] = 1;     // Set mutability
        sym_funcsig[sym_count] = "-";
        sym_count++;
        next_addr++;
    }
    | LET MUT IDENT ':' '&' STR '=' Expr ';' {
        insert_sym_entry($3, next_addr, current_scope_level, yylineno);
        sym_names[sym_count] = strdup($3);
        sym_addrs[sym_count] = next_addr;
        sym_scopes[sym_count] = current_scope_level;
        sym_linenos[sym_count] = yylineno;
        sym_types[sym_count] = "str";
        sym_mut[sym_count] = 1;     // Set mutability
        sym_funcsig[sym_count] = "-";
        sym_count++;
        next_addr++;
    }
    | IDENT '=' Expr ';' { printf("ASSIGN\n"); }
    | IDENT ADD_ASSIGN Expr ';' { printf("ADD_ASSIGN\n"); }
    | IDENT SUB_ASSIGN Expr ';' { printf("SUB_ASSIGN\n"); }
    | IDENT MUL_ASSIGN Expr ';' { printf("MUL_ASSIGN\n"); }
    | IDENT DIV_ASSIGN Expr ';' { printf("DIV_ASSIGN\n"); }
    | IDENT REM_ASSIGN Expr ';' { printf("REM_ASSIGN\n"); }
    | '{' { current_scope_level++; create_sym_table(); } StmtList '}' {
        dump_sym_table(current_scope_level);
        while (sym_count > 0 && sym_scopes[sym_count-1] == current_scope_level) sym_count--;
        current_scope_level--;
    }
    | PRINTLN '(' Expr ')' ';' {
        printf("PRINTLN %s\n", $3);
    }
    | PRINT '(' Expr ')' ';' { printf("PRINT %s\n", $3); }
    | PrintStmt
    | NEWLINE
;

Expr
    : INT_LIT { printf("INT_LIT %d\n", $1); $$ = "i32"; }
    | FLOAT_LIT { printf("FLOAT_LIT %f\n", $1); $$ = "f32"; }
    | '"' '"' { printf("STRING_LIT \"\"\n"); $$ = "str"; }
    | '"' STRING_LIT '"' { printf("STRING_LIT \"%s\"\n", $2); $$ = "str"; }
    | IDENT { printf("IDENT (name=%s, address=%d)\n", $1, lookup_addr($1)); $$ = lookup_type($1); }
    | TRUE { printf("bool TRUE\n"); $$ = "bool"; }
    | FALSE { printf("bool FALSE\n"); $$ = "bool"; }
    | '-' Expr %prec UMINUS { printf("NEG\n"); $$ = $2; }
    | '!' Expr { printf("NOT\n"); $$ = $2; }
    | '(' Expr ')' { $$ = $2; }
    | Expr '*' Expr { printf("MUL\n"); $$ = $1; }
    | Expr '/' Expr { printf("DIV\n"); $$ = $1; }
    | Expr '%' Expr { printf("REM\n"); $$ = $1; }
    | Expr '+' Expr { printf("ADD\n"); $$ = $1; }
    | Expr '-' Expr { printf("SUB\n"); $$ = $1; }
    | Expr '>' Expr { printf("GTR\n"); $$ = "bool"; }
    | Expr LAND Expr { printf("LAND\n"); $$ = "bool"; }
    | Expr LOR Expr { printf("LOR\n"); $$ = "bool"; }
;

PrintStmt
    : PRINTLN '(' STRING_LIT ')' ';' { 
        printf("STRING_LIT \"%s\"\n", $3);
        printf("PRINTLN str\n");
    }
;

%%

/* C code section */
int main(int argc, char *argv[])
{
    if (argc == 2) {
        yyin = fopen(argv[1], "r");
    } else {
        yyin = stdin;
    }

    yylineno = 1; 
    
    create_sym_table(); 
    
    yyparse();

    int total_lines_to_print = yylineno;
    if (total_lines_to_print > 0) { 
        total_lines_to_print--;
    }
	printf("Total lines: %d\n", total_lines_to_print);
    
    fclose(yyin);
    return 0;
}

static void create_sym_table() {
    printf("> Create symbol table (scope level %d)\n", current_scope_level);
}

static void insert_sym_entry(const char* name, int addr, int scope_level, int lineno) {
    printf("> Insert `%s` (addr: %d) to scope level %d\n", name, addr, scope_level);
}

static void dump_sym_table(int scope_level) {
    printf("\n> Dump symbol table (scope level: %d)\n", scope_level);
    printf("%-10s%-10s%-10s%-10s%-10s%-10s%-10s\n",
        "Index", "Name", "Mut","Type", "Addr", "Lineno", "Func_sig");
    int local_idx = 0;
    for (int i = 0; i < sym_count; i++) {
        if (sym_scopes[i] == scope_level) {
            int mut_flag;
            if (strcmp(sym_types[i], "func") == 0) {
                mut_flag = -1;
            } else {
                mut_flag = sym_mut[i]; // Use stored mutability
            }
            printf("%-10d%-10s%-10d%-10s%-10d%-10d%-10s\n",
                local_idx, sym_names[i], mut_flag, sym_types[i], sym_addrs[i], sym_linenos[i], sym_funcsig[i]);
            local_idx++;
        }
    }
}

int lookup_addr(const char *name) {
    for (int i = sym_count - 1; i >= 0; i--) {
        if (strcmp(sym_names[i], name) == 0) return sym_addrs[i];
    }
    return -1;
}

char *lookup_type(const char *name) {
    for (int i = sym_count - 1; i >= 0; i--) {
        if (strcmp(sym_names[i], name) == 0) return sym_types[i];
    }
    return "";
}