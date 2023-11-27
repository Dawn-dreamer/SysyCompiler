%{
#include <bits/stdc++.h>
using namespace std;

extern int yylex(void); 
extern int yyparse(void); 
void yyerror(const char *s){
	cout<<"error"<<endl;;
}
enum OP
{
    EQ_OP,NEQ_OP,LT_OP,GT_OP,LEQ_OP,GEQ_OP,PLUS_OP,MINUS_OP,MUL_OP,DIV_OP,MOD_OP,AND_OP,OR_OP,NOT_OP,ASSIGN_OP
};


enum Type {Int, Constint,Void, Arr, Fint, Fvoid,ConstArr};
struct Var{
	Type type;
	int value, offset;
	vector<int> dim;
    string addr;
    int unit_size;
    int level;
	Var() {}
	Var(Type _type, int _val) : type(_type), value(_val){}
	Var(Type _type, int _val, int _offset) : type(_type), value(_val), offset(_offset){}
	Var(Type _type, int _val, int _offset, vector<int> _dim) : type(_type), value(_val), offset(_offset), dim(_dim){}
    Var(Type _type, vector<int> _dim) : type(_type), dim(_dim){}
};

struct Func
{
    string name;
    Type ftype;
    int rsp_asmidx;
    vector<int> ret_idxs;
    vector<pair<string,Type>> paras;//n n-1 ... 1
    int var_offset;
}func_buffer;

struct Decl
{
    bool is_global;
    Type type;
    bool is_const;
}decl_buffer;


struct Node {
    int value;
    bool is_const;
    int offset;
    bool is_global;
    const char* name;
    bool is_array;
    int idx_offset;
    Node()=default;
    Node(int _value, bool _is_const) 
    {
        is_array=false;
        is_global=false;
        is_const=_is_const;
        if(is_const)
            value=_value;
        else
            offset=_value;
        
    }
    Node(const char* _name)
    {
        is_array=false;
        is_global=true;
        is_const=false;
        name=_name;
    }
};

int get_offset(Node&n1,Node&n2)
{
    if(n1.is_const)
        return n2.offset;
    else
        return n1.offset;
}
struct Array
{
    vector<int> dim;
    vector<int> unit_dims;
    int cnt;
    int unit_size;
    Array(vector<int> _dim)
    {
        dim=_dim;
        cnt=0;
        unit_size=0;
    }
    Array()=default;
    void set_unit_dims()
    {
        int mul=1,begin=dim.size()-1;
        unit_size=1;
        int i;
        for(i=begin;i>0;i--)
        {
            mul*=dim[i];
            if(cnt%mul==0)
                {
                    unit_size*=dim[i];
                }
            else
                break;
        }
        for(i=i+1;i<=begin;i++)
        {
            unit_dims.push_back(dim[i]);
        }
    }
};

int label_count = 0;
vector<map<string, Var> > var_table;
map<string, Var> global_var_table;//全局变量表,属性包括type
map<string, Func> func_table;
vector<vector<int>> break_lists;
vector<vector<int>> continue_lists;
vector<string>assembly_code;


vector<int> array_dim_buffer;//arr[a][b][c]... 
vector<int> array_item_buffer;
vector<Array> array_struct_buffer;

vector<Var> var_buffer;

void output_assembly_code()
{
    for(auto s:assembly_code)
        cout<<s<<endl;
}
inline int align16(int n) {
    return (n >> 4) << 4;
}
int setlabel()
{
    assembly_code.push_back(".L"+to_string(label_count)+":");
    return label_count++;
}

%}
%union 
{
    std::string *str_val;
    int int_val;
    char char_val;
    OP op_val;
    Node node_val;
}

%token INT RETURN GEQ LEQ EQ NEQ AND OR CONST IF ELSE WITHOUTELSE WHILE BREAK CONTINUE VOID
%token SCANF PRINTF
%token <str_val> IDENT 
%token <int_val> INT_CONST
%type  <op_val> EqOp RelOp AddOp MulOp UnaryOp
%type <int_val> Number ConstInitVal ConstExp
%type <node_val>  PrimaryExp UnaryExp MulExp AddExp RelExp EqExp LAndExp LOrExp Exp
%type<node_val>   LVal InitVal  
%type<int_val> SetLabel Placeholder
%type<int_val> FuncRParams FuncRParamsList 
%type<str_val> ArrName
%nonassoc WITHOUTELSE
%nonassoc ELSE

%%

/* CompUnit
    : FuncDef
    {

    }
    | CompUnit FuncDef
    {

    }
    | CompUnit GlobalInit Decl 
    {

    } 
    ; */
CompUnits : GlobalInit CompUnit {}
            |GlobalInit CompUnit  CompUnits {}

CompUnit : FuncDef {}
            | Decl {}
GlobalInit
    :
    {
        decl_buffer.is_global=true;
    }
FuncInit
    :/*empty*/
    {
        auto iter=func_table.find(func_buffer.name);
        if(iter!=func_table.end())
            cout<<"error func init"<<endl;
        else
            func_table[func_buffer.name]=func_buffer;
        assembly_code.push_back("\t.text");
        assembly_code.push_back("\t.globl\t"+func_buffer.name);
        assembly_code.push_back("\t.type\t"+func_buffer.name+", @function");
        assembly_code.push_back(func_buffer.name+":");
        assembly_code.push_back("\tpushq\t%rbp");
        assembly_code.push_back("\tmovq\t%rsp, %rbp");
        assembly_code.push_back("\tpushq\t%r8");
        assembly_code.push_back("\tpushq\t%r9");
        func_buffer.var_offset = -16;
        assembly_code.push_back("");//移动rsp的指令的下标
        func_buffer.rsp_asmidx = assembly_code.size()-1;
        //形参和实参结合
        int offset=16;
        for(auto para:func_buffer.paras)
        {
            var_table.back()[para.first]=Var(para.second,0,offset);
            offset+=4;
        }
    }
    ;

FuncDef
    : UType FName '(' FuncFParams ')'  BeforeBlock FuncInit  Block   AfterBlock
    {   
        //手动加上ret指令
        assembly_code.push_back("");
        func_buffer.ret_idxs.push_back(assembly_code.size()-1);
        assembly_code.push_back("\tpopq\t%r9");
        assembly_code.push_back("\tpopq\t%r8");
        assembly_code.push_back("\tpopq\t%rbp");
        assembly_code.push_back("\tret");
        //16位对齐
        func_buffer.var_offset=align16(func_buffer.var_offset);


        assembly_code[func_buffer.rsp_asmidx] = "\tsubq\t$"+to_string(-func_buffer.var_offset-16)+", %rsp";
        for (auto i:func_buffer.ret_idxs)
            assembly_code[i] = "\taddq\t$"+to_string(-func_buffer.var_offset-16)+", %rsp";
        
        func_buffer.ret_idxs.clear();
        func_buffer.paras.clear();
        func_buffer.var_offset=0;
    }
    ;
FuncFParams
    : FuncFparam FuncFParamlists
    {

    }
    |/* empty */
    {

    }
    ;
FuncFParamlists
    :/* emtpy*/
    {

    }
    | ','  FuncFparam  FuncFParamlists
    {

    }
    ;
FuncFparam
    : UType IDENT
    {
        func_buffer.paras.push_back(make_pair(*$2, Int));
    }
    ;
FName
    :
    IDENT
    {
        func_buffer.name = *$1;


    }


UType
    : INT
    {
        func_buffer.ftype = Fint;
        decl_buffer.type = Int;
    }
    | VOID
    {
        func_buffer.ftype = Fvoid;
        decl_buffer.type = Void;
    }
    ;
BeforeBlock
    :
    {
        var_table.push_back(map<string, Var>());
    }
    ;
AfterBlock
    :
    {
        var_table.pop_back();
    }
    ;
Block 
    :'{' BlockItemList '}'
    {

    }
    ;

BlockItemList
    : BlockItem BlockItemList
    {

    }
    | /* empty */
    {

    }
    ;
BlockItem
    : Stmt
    {

    }
    |LocalInit Decl
    {

    }
    ;
LocalInit
    :
    {
        decl_buffer.is_global=false;
    }
    ;
Stmt 
    : RETURN Exp ';'
    {
        if(func_buffer.ftype == Fvoid)
        {
            //报错
            cout<<"void function can't return value"<<endl;
            exit(1);
        }
        if($2.is_const)
            assembly_code.push_back("\tmovl\t$"+to_string($2.value)+", %eax");
        else
            assembly_code.push_back("\tmovl\t"+to_string($2.offset)+"(%rbp), %eax");
        assembly_code.push_back("");
        func_buffer.ret_idxs.push_back(assembly_code.size()-1);
        assembly_code.push_back("\tpopq\t%r9");
        assembly_code.push_back("\tpopq\t%r8");
        assembly_code.push_back("\tpopq\t%rbp");
        assembly_code.push_back("\tret");
    }
    | RETURN ';'
    {
        if(func_buffer.ftype==Fint)
        {
            //报错
            cout<<"int function must return value"<<endl;
            exit(1);
        }
        assembly_code.push_back("");
        func_buffer.ret_idxs.push_back(assembly_code.size()-1);
        assembly_code.push_back("\tpopq\t%r9");
        assembly_code.push_back("\tpopq\t%r8");
        assembly_code.push_back("\tpopq\t%rbp");
        assembly_code.push_back("\tret");
    }
    | LVal '=' Exp ';'
    {
        if($1.is_const)
            {
                // cout<<"Invalid assignment to const"<<endl;
                cout<<"Invalid assignment to const"<<endl;
                exit(1);
            }
        if($3.is_const)
            assembly_code.push_back("\tmovl\t$"+to_string($3.value)+", %eax");
        else
            assembly_code.push_back("\tmovl\t"+to_string($3.offset)+"(%rbp), %eax");
        string addr;
        if($1.is_array)
            {
                assembly_code.push_back("\tmovq\t"+to_string($1.idx_offset)+"(%rbp), %rcx");
                assembly_code.push_back("\tmovl\t%eax,\t(%rcx)");
                goto end;
            }
        if($1.is_global)
            addr = string($1.name)+"(%rip)";
        else
            addr = to_string($1.offset)+"(%rbp)";
   // assembly_code.push_back("\tmovl\t%eax, "+to_string($1.offset)+"(%rbp)");
        assembly_code.push_back("\tmovl\t%eax, "+addr);
        end:
            ;
    }
    | Exp ';'
    {

    }
    | ';'
    {

    }
    | BeforeBlock  Block   AfterBlock
    {

    }
    ;
    | IF '(' Exp ')' Placeholder Stmt Placeholder SetLabel %prec WITHOUTELSE
    {
        //判断Exp是否为0，为0:跳转到SetLabel1 
        int back_idx=$5;
        int label=$8;
        string back_string;
        if($3.is_const)
        {
            if($3.value==0)
                back_string="\tjmp\t.L"+to_string(label);
            else
                back_string="";
        }
        else
        {
            back_string="\tmovl\t"+to_string($3.offset)+"(%rbp), %eax\n"
                        +"\tcmpl\t$0, %eax\n"
                        +"\tje\t.L"+to_string(label);
            
        }
        assembly_code[back_idx]=back_string;
        // assembly_code[back_idx]="\tmovl\t"+to_string(exp_offset)+"(%rbp), %eax\n"
        //                         +"\tcmpl\t$0, %eax\n"
        //                         +"\tje\t.L"+to_string(label)+"\n";
    }
    | IF '(' Exp ')' Placeholder Stmt Placeholder SetLabel ELSE  Stmt SetLabel
    {
        //判断Exp是否为0，为0:跳转到SetLabel1 
        int back_idx1=$5;
        int back_idx2=$7;
        int label1=$8;
        int label2=$11;
        // int exp_offset=$3.offset;
        // assembly_code[back_idx1]="\tmovl\t"+to_string(exp_offset)+"(%rbp), %eax\n"
        //                         +"\tcmpl\t$0, %eax\n"
        //                         +"\tje\t.L"+to_string(label1)+"\n";
        // assembly_code[back_idx2]="\tjmp\t.L"+to_string(label2)+"\n";
        string back_string1,back_string2;
        if($3.is_const)
        {
            if($3.value==0)
                back_string1="\tjmp\t.L"+to_string(label1);
            else
                back_string1="";
        }
        else
        {
            back_string1="\tmovl\t"+to_string($3.offset)+"(%rbp), %eax\n"
                        +"\tcmpl\t$0, %eax\n"
                        +"\tje\t.L"+to_string(label1);
        }
        assembly_code[back_idx1]=back_string1;
        assembly_code[back_idx2]="\tjmp\t.L"+to_string(label2);
    }
    |  WHILE AfterWhile SetLabel '(' Exp ')'  Placeholder Stmt 
    {
        //判断Exp是否为0，为0:跳转到SetLabel1 
        assembly_code.push_back("\tjmp\t.L"+to_string($3));
        int exit_label=setlabel();
        string back_string;
        if($5.is_const)
        {
            if($5.value==1)
                back_string="";
            else
                back_string="\tjmp\t.L"+to_string(exit_label);
        }
        else
        {
            back_string="\tmovl\t"+to_string($5.offset)+"(%rbp), %eax\n"
                        +"\tcmpl\t$0, %eax\n"
                        +"\tje\t.L"+to_string(exit_label);
        }   
        assembly_code[$7]=back_string;
        for (auto i:break_lists.back())
            assembly_code[i]="\tjmp\t.L"+to_string(exit_label);
        for (auto i:continue_lists.back())
            assembly_code[i]="\tjmp\t.L"+to_string($3);
        break_lists.pop_back();
        continue_lists.pop_back();  
    }
    |  BREAK ';'
    {
        assembly_code.push_back("");
        break_lists.back().push_back(assembly_code.size()-1);
    }
    |  CONTINUE ';'
    {
        assembly_code.push_back("");
        continue_lists.back().push_back(assembly_code.size()-1);
    }

    ;
AfterWhile
    :/*empty*/
    {
        break_lists.push_back(vector<int>());
        continue_lists.push_back(vector<int>());
    }
    ;
Placeholder
    :/*empty*/
    {
        assembly_code.push_back("");
        $$=assembly_code.size()-1;
    }
    ;

Exp 
    : LOrExp
    {
        $$=$1;
    }
    ;

LOrExp
    : LAndExp
    {
        $$=$1;
    }
    | LOrExp OR Placeholder LAndExp
    {
        if($1.is_const&&$4.is_const)
        {
            $$=Node($1.value||$4.value,true);
        }
        else
        {
            int cur_label_idx=label_count;
            string back_string,end_string;
            if($1.is_const)
            {
                if($1.value==1)
                {
                    back_string="\tjmp\t.L"+to_string(cur_label_idx);
                }
                else
                {
                    back_string="";
                }
            }
            else
            {
                back_string="\tmovl\t"+to_string($1.offset)+"(%rbp), %eax\n"
                            +"\tcmpl\t$0, %eax\n"
                            +"\tjne\t.L"+to_string(cur_label_idx)+"\n";
            }
            if($4.is_const)
            {
                if($4.value==1)
                {
                    end_string="\tjmp\t.L"+to_string(cur_label_idx)+"\n";
                }
                else
                {
                    end_string="";
                }
            }
            else
            {
                end_string="\tmovl\t"+to_string($4.offset)+"(%rbp), %eax\n"
                            +"\tcmpl\t$0, %eax\n"
                            +"\tjne\t.L"+to_string(cur_label_idx)+"\n";
            }
            end_string+="\tjmp\t.L"+to_string(cur_label_idx+1);
            assembly_code[$3]=back_string;
            assembly_code.push_back(end_string);
            setlabel();
            $$=Node(get_offset($1,$4),false);
            end_string="\tmovl\t$1, "+to_string(get_offset($1,$4))+"(%rbp)\n";
            end_string+="\tjmp\t.L"+to_string(cur_label_idx+2)+"\n";
            assembly_code.push_back(end_string);
            setlabel();
            assembly_code.push_back("\tmovl\t$0, "+to_string(get_offset($1,$4))+"(%rbp)");
            setlabel();
        }


    }
    ;

SetLabel
    :/*empty*/
    {
        $$=setlabel();
    }

LAndExp
    : EqExp
    {
        $$=$1;
    }
    | LAndExp AND Placeholder EqExp
    {
        if($1.is_const && $4.is_const)
        {
            $$=Node($1.value && $4.value, true);
        }
        else
        {
            int cur_label_idx=label_count;
            string back_string, end_string;

            if($1.is_const)
            {
                if($1.value == 0)
                {
                    back_string="\tjmp\t.L" + to_string(cur_label_idx);
                }
                else
                {
                    back_string="";
                }
            }
            else
            {
                back_string="\tmovl\t" + to_string($1.offset) + "(%rbp), %eax\n"
                            +"\tcmpl\t$0, %eax\n"
                            +"\tje\t.L" + to_string(cur_label_idx) + "\n";
            }

            if($4.is_const)
            {
                if($4.value == 0)
                {
                    end_string="\tjmp\t.L" + to_string(cur_label_idx) + "\n";
                }
                else
                {
                    end_string="";
                }
            }
            else
            {
                end_string="\tmovl\t" + to_string($4.offset) + "(%rbp), %eax\n"
                            +"\tcmpl\t$0, %eax\n"
                            +"\tje\t.L" + to_string(cur_label_idx) + "\n";
            }

            end_string+="\tjmp\t.L" + to_string(cur_label_idx + 1);
            assembly_code[$3]=back_string;
            assembly_code.push_back(end_string);
            setlabel();

            // 创建新的变量
            $$=Node(get_offset($1, $4), false);
            end_string="\tmovl\t$0, " + to_string(get_offset($1, $4)) + "(%rbp)\n";
            end_string+="\tjmp\t.L" + to_string(cur_label_idx + 2) + "\n";
            assembly_code.push_back(end_string);
            setlabel();
            assembly_code.push_back("\tmovl\t$1, " + to_string(get_offset($1, $4)) + "(%rbp)");
            setlabel();
        }
    }
    ;

EqOp
    : EQ
    {
        $$=EQ_OP;
    }
    |
    NEQ
    {
        $$=NEQ_OP;
    }
    ;

EqExp
    : RelExp
    {
        $$=$1;
    }
    | EqExp EqOp RelExp
    {
        // $$=$2==EQ_OP?$1==$3:$1!=$3;
        if($1.is_const&&$3.is_const)
        {
            switch ($2)
            {
            case EQ_OP:
                $$=Node($1.value==$3.value,true);
                break;
            case NEQ_OP:
                $$=Node($1.value!=$3.value,true);
                break;
            default:
                break;
            }
        }
        else
        {
            if($1.is_const)
                assembly_code.push_back("\tmovl\t$"+to_string($1.value)+", %r8d");
            else
                assembly_code.push_back("\tmovl\t"+to_string($1.offset)+"(%rbp), %r8d");
            if($3.is_const)
                // cout<<"\tcmpl\t$"<<$3.value<<", %r9d"<<endl;
                assembly_code.push_back("\tmovl\t$"+to_string($3.value)+", %r9d");
            else
                // cout<<"\tcmpl\t"<<$3.offset<<"(%rbp), %r9d"<<endl;
                assembly_code.push_back("\tmovl\t"+to_string($3.offset)+"(%rbp), %r9d");
            // cout<<"\tcmp\t%r9d, %r8d"<<endl;
            assembly_code.push_back("\tcmpl\t%r9d, %r8d");
            if($2==EQ_OP)
                assembly_code.push_back("\tsete\t%r8b");
            else
                assembly_code.push_back("\tsetne\t%r8b");
            assembly_code.push_back("\tmovzbl\t%r8b, %r8d");
            int ans_offset = $1.is_const?$3.offset:$1.offset;
            assembly_code.push_back("\tmovl\t%r8d, "+to_string(ans_offset)+"(%rbp)");            
            $$=Node(ans_offset,false);
        }
    }
    ;
RelOp
    : '<'
    {
        $$=LT_OP;
    }
    | '>'
    {
        $$=GT_OP;
    }
    | LEQ
    {
        $$=LEQ_OP;
    }
    | GEQ
    {
        $$=GEQ_OP;
    }

RelExp
    : AddExp
    {
        $$=$1;
    }
    | RelExp RelOp AddExp
    {
        if($1.is_const&&$3.is_const)
        {
            switch ($2)
            {
            case LT_OP:
                $$=Node($1.value<$3.value,true);
                break;
            case GT_OP:
                $$=Node($1.value>$3.value,true);
                break;
            case LEQ_OP:
                $$=Node($1.value<=$3.value,true);
                break;
            case GEQ_OP:
                $$=Node($1.value>=$3.value,true);
                break;
            default:
                break;
            }
        }
        else 
        {
            if($1.is_const)
                assembly_code.push_back("\tmovl\t$"+to_string($1.value)+", %r8d");
            else
                assembly_code.push_back("\tmovl\t"+to_string($1.offset)+"(%rbp), %r8d");
            if($3.is_const)
                assembly_code.push_back("\tmovl\t$"+to_string($3.value)+", %r9d");
            else
                assembly_code.push_back("\tmovl\t"+to_string($3.offset)+"(%rbp), %r9d");
            //cout<<"\tcmpl\t%r9d, %r8d"<<endl;
            assembly_code.push_back("\tcmpl\t%r9d, %r8d");
            
            switch ($2)
            {
            case LT_OP:
                // cout<<"\tsetl\t%al"<<endl;
                assembly_code.push_back("\tsetl\t%al");
                break;
            case GT_OP:
                // cout<<"\tsetg\t%al"<<endl;
                assembly_code.push_back("\tsetg\t%al");
                break;
            case LEQ_OP:
                // cout<<"\tsetle\t%al"<<endl;
                assembly_code.push_back("\tsetle\t%al");
                break;
            case GEQ_OP:
                // cout<<"\tsetge\t%al"<<endl;
                assembly_code.push_back("\tsetge\t%al");
                break;
            default:
                break;
            }
            // cout<<"\tmovzbl\t%al, %eax"<<endl;
            assembly_code.push_back("\tmovzbl\t%al, %eax");
            int ans_offset=get_offset($1,$3);
            // cout<<"\tmovl\t%eax, "<<ans_offset<<"(%rbp)"<<endl;
            assembly_code.push_back("\tmovl\t%eax, "+to_string(ans_offset)+"(%rbp)");
            $$=Node(ans_offset,false);
        }
    }
    ;

AddOp
    : '+'
    {
        $$=PLUS_OP;
    }
    | '-'
    {
        $$=MINUS_OP;
    }

AddExp
    : MulExp
    {
        $$=$1;
    }
    | AddExp AddOp MulExp
    {
        if($1.is_const&&$3.is_const)
        {
            $$=Node($2==PLUS_OP? $1.value+$3.value:$1.value-$3.value,true);
        }
        else 
        {
            if($1.is_const)
                assembly_code.push_back("\tmovl\t$"+to_string($1.value)+", %r8d");
            else
                assembly_code.push_back("\tmovl\t"+to_string($1.offset)+"(%rbp), %r8d");
            if($3.is_const)
                assembly_code.push_back("\tmovl\t$"+to_string($3.value)+", %r9d");
            else
                assembly_code.push_back("\tmovl\t"+to_string($3.offset)+"(%rbp), %r9d");

            if($2==PLUS_OP)
                // cout<<"\taddl\t%r9d, %r8d"<<endl;
                assembly_code.push_back("\taddl\t%r9d, %r8d");
            else
                // cout<<"\tsubl\t%r9d, %r8d"<<endl;
                assembly_code.push_back("\tsubl\t%r9d, %r8d");
            int ans_offset=get_offset($1,$3);

            assembly_code.push_back("\tmovl\t%r8d, "+to_string(ans_offset)+"(%rbp)");
            $$=Node(ans_offset,false);
        }
    }
    ;


MulOp
    :
    '*'
    {
        $$=MUL_OP;
    }
    | '/'
    {
        $$=DIV_OP;
    }
    | '%'
    {
        $$=MOD_OP;
    }
    ;

MulExp
    : UnaryExp
    {
        $$=$1;
    }
    | MulExp MulOp UnaryExp
    {
        if($1.is_const&&$3.is_const)
        {
            switch ($2)
            {
            case MUL_OP:
                $$=Node($1.value*$3.value,true);
                break;
            case DIV_OP:
                $$=Node($1.value/$3.value,true);
                break;
            case MOD_OP:
                $$=Node($1.value%$3.value,true);
                break;
            default:
                break;
            }
        }
        else 
        {
            if($1.is_const)
                assembly_code.push_back("\tmovl\t$"+to_string($1.value)+", %r8d");
            else
                assembly_code.push_back("\tmovl\t"+to_string($1.offset)+"(%rbp), %r8d");
            if($3.is_const)
                assembly_code.push_back("\tmovl\t$"+to_string($3.value)+", %r9d");
            else
                assembly_code.push_back("\tmovl\t"+to_string($3.offset)+"(%rbp), %r9d");
            switch ($2)
            {
            case MUL_OP:
                // cout<<"\timull\t%r9d, %r8d"<<endl;
                assembly_code.push_back("\timull\t%r9d, %r8d");
                break;
            case DIV_OP:
                // cout<<"\tmovl\t%r8d, %eax"<<endl;
                // cout<<"\tcltd"<<endl;
                // cout<<"\tidivl\t%r9d"<<endl;
                // cout<<"\tmovl\t%eax, %r8d"<<endl;
                assembly_code.push_back("\tmovl\t%r8d, %eax");
                assembly_code.push_back("\tcltd");
                assembly_code.push_back("\tidivl\t%r9d");
                assembly_code.push_back("\tmovl\t%eax, %r8d");

                break;
            case MOD_OP:
                // cout<<"\tmovl\t%r8d, %eax"<<endl;
                // cout<<"\tcltd"<<endl;
                // cout<<"\tidivl\t%r9d"<<endl;
                // cout<<"\tmovl\t%edx, %r8d"<<endl;
                assembly_code.push_back("\tmovl\t%r8d, %eax");
                assembly_code.push_back("\tcltd");
                assembly_code.push_back("\tidivl\t%r9d");
                assembly_code.push_back("\tmovl\t%edx, %r8d");

                break;
            default:
                break;
            }
            int ans_offset=get_offset($1,$3);

            assembly_code.push_back("\tmovl\t%r8d, "+to_string(ans_offset)+"(%rbp)");
            $$=Node(ans_offset,false);
        }
    }
    ;

UnaryExp
    : PrimaryExp
    {
        $$=$1;
    }
    | UnaryOp UnaryExp
    {
        if($2.is_const)
            {
                switch ($1)
                {
                case PLUS_OP:
                    $$=Node($2.value,true);
                    break;
                case MINUS_OP:
                    $$=Node(-$2.value,true);
                    break;
                case NOT_OP:
                    $$=Node(!$2.value,true);
                    break;
                default:
                    break;
                }
            }
        else
            {
                switch ($1)
                {
                case PLUS_OP:
                    break;
                case MINUS_OP:
                    assembly_code.push_back("\tmovl\t"+to_string($2.offset)+"(%rbp), %r8d");
                    assembly_code.push_back("\tnegl\t%r8d");
                    assembly_code.push_back("\tmovl\t%r8d, "+to_string($2.offset)+"(%rbp)");
                    break;
                case NOT_OP:
                    assembly_code.push_back("\tmovl\t"+to_string($2.offset)+"(%rbp), %r8d");
                    // assembly_code.push_back("\tnotl\t%r8d");
                    // assembly_code.push_back("\tmovzbl\t%r8d, "+to_string($2.offset)+"(%rbp)");
                    assembly_code.push_back("\tcmpl\t$0, %r8d");
                    assembly_code.push_back("\tsete\t%r8b");
                    assembly_code.push_back("\tmovzbl\t%r8b, %r8d");
                    assembly_code.push_back("\tmovl\t%r8d, "+to_string($2.offset)+"(%rbp)");
                    
                    break;
                default:
                    break;
                }
                $$=$2;
            }
    }
    | SCANF '(' LVal ')'
    {

        string addr;
        if($3.is_array)
            {
                assembly_code.push_back("\tmovq\t"+to_string($3.idx_offset)+"(%rbp), %rsi");
            }
        else 
        {
            if($3.is_global)
                addr = string($3.name)+"(%rip)";
            else
                addr = to_string($3.offset)+"(%rbp)";
            assembly_code.push_back("\tleaq\t"+addr+", %rsi");
        }
        assembly_code.push_back("\tleaq\t.LC0(%rip),\t%rdi");
        assembly_code.push_back("\tcall\t__isoc99_scanf@PLT");
    }
    | PRINTF '(' Exp ')'
    {
        if($3.is_const)
        {
            assembly_code.push_back("\tmovl\t$"+to_string($3.value)+", %esi");
        }
        else
        {
            assembly_code.push_back("\tmovl\t"+to_string($3.offset)+"(%rbp), %esi");
        }

        assembly_code.push_back("\tleaq\t.LC1(%rip),\t%rdi");
        assembly_code.push_back("\tcall\tprintf@PLT");
    }
    | 
        IDENT '(' FuncRParams ')' 
    {
        // Func & called_func=func_table[*$1];
        auto iter=func_table.find(*$1);
        if(iter==func_table.end())
        {
            cout<<"Error : Function "<<*$1<<" is not defined"<<endl;
            exit(1);
        }
        Func & called_func=iter->second;
        //检查形参和实参的个数和类型
        if(called_func.paras.size()!=$3)
        {
            cout<<"Error : Function "<<$1<<" is not applicable for arguments"<<endl;
            cout<<"Error : Function "<<$1<<" has "<<called_func.paras.size()<<" parameters"<<endl;
            cout<<"Error : Function "<<$1<<" is called with "<<$3<<" arguments"<<endl;
            exit(1);
        }
        assembly_code.push_back("\tcall\t"+*$1);
        assembly_code.push_back("\taddq\t$"+to_string($3*4)+", %rsp");
        func_buffer.var_offset+=$3*4;
        func_buffer.var_offset-=4;
        $$=Node(func_buffer.var_offset,false);
        assembly_code.push_back("\tmovl\t%eax, "+to_string($$.offset)+"(%rbp)");
    }

    ;
FuncRParams
    :/*empty*/
    {
        $$=0;
    }
    | Exp FuncRParamsList
    {
        func_buffer.var_offset-=4;
        assembly_code.push_back("\tsubq\t$4, %rsp");
        if($1.is_const)
            assembly_code.push_back("\tmovl\t$"+to_string($1.value)+", "+"(%rsp)");
        else
            // assembly_code.push_back("\tmovl\t"+to_string($1.offset)+"(%rbp), "+"(%rsp)");
            {
                assembly_code.push_back("\tmovl\t"+to_string($1.offset)+"(%rbp), %r8d");
                assembly_code.push_back("\tmovl\t%r8d, (%rsp)");
            }
        $$=1+$2;
    }
    ;

FuncRParamsList
    :
    /*empty*/
    {
        $$=0;
    }
    | ',' Exp FuncRParamsList
    {
        func_buffer.var_offset-=4;
        assembly_code.push_back("\tsubq\t$4, %rsp");
        if($2.is_const)
            assembly_code.push_back("\tmovl\t$"+to_string($2.value)+", "+"(%rsp)");
        else
            // assembly_code.push_back("\tmovl\t"+to_string($2.offset)+"(%rbp), "+"(%rsp)");
            {
                assembly_code.push_back("\tmovl\t"+to_string($2.offset)+"(%rbp), %r8d");
                assembly_code.push_back("\tmovl\t%r8d, (%rsp)");
            }
        $$=1+$3;
    }
    ;

UnaryOp
    : '+'
    {
        $$=PLUS_OP;
    }
    | '-'
    {
        $$=MINUS_OP;
    }
    | '!'
    {
        $$=NOT_OP;
    }
    ;

PrimaryExp 
    : '(' Exp ')'
    {
        $$=$2;
    }
    | Number
    {
        $$=Node($1,true);
    }
    | LVal
    {
        if($1.is_const)
            $$=$1;
        else
        {
            string addr;
            if($1.is_global)
            {
                addr=string($1.name)+"(%rip)";
            }
            else
            {
                addr=to_string($1.offset)+"(%rbp)";
            }
            func_buffer.var_offset-=4;
            // assembly_code.push_back("\tmovl\t"+to_string($1.offset)+"(%rbp), %r8d");
            assembly_code.push_back("\tmovl\t"+addr+", %r8d");
            assembly_code.push_back("\tmovl\t%r8d, "+to_string(func_buffer.var_offset)+"(%rbp)");
            $$=Node(func_buffer.var_offset,false);
        }
    }
    ;

Number
    : INT_CONST
    {
        $$=$1;
    }
    ;
Decl
    : ConstDecl
    {

    }
    | VarDecl
    {

    }
    ;
ConstDecl
    : CONST UType BeforeConstDef ConstDef ConstDefList AfterConstDef';'
    {

    }
    ;

VarDecl 
    : UType  VarDef  VarDefList ';'
    {

    }
    ;

AfterConstDef
    :
    /* empty */
    {
        decl_buffer.is_const = false;
    }
    ;
VarDef 
    : IDENT
    {
        if(decl_buffer.is_global==false)
        {
            //查找是否已经定义过
            if(var_table.back().find(*$1)!=var_table.back().end())
            {
                cout<<"redefined variable "<<$1<<endl;
                exit(1);
            }
            else
            {
                //分配空间
                // assembly_code.push_back("\tsubq\t$4, %rsp");
                func_buffer.var_offset-=4;
                //加入符号表
                var_table.back()[*$1]=Var(decl_buffer.type,0,func_buffer.var_offset);
            }
        }
        else
        {
            if(global_var_table.find(*$1)!=global_var_table.end())
            {
                cout<<"redefined variable "<<$1<<endl;
                exit(1);
            }
            else
            {
                //加入符号表
                global_var_table[*$1]=Var(decl_buffer.type,0);
                assembly_code.push_back("\t.globl\t"+*$1);
                assembly_code.push_back("\t.data");
                assembly_code.push_back("\t.align\t4");
                assembly_code.push_back("\t.type\t"+*$1+", @object");
                assembly_code.push_back("\t.size\t"+*$1+", 4");
                assembly_code.push_back(*$1+":");
                assembly_code.push_back("\t.long\t0");
            }
        }
    }
    | IDENT '=' InitVal
    {
        if(decl_buffer.is_global==false)
        {
            //查找是否已经定义过
            if(var_table.back().find(*$1)!=var_table.back().end())
            {
                cout<<"redefined variable "<<$1<<endl;
                exit(1);
            }
            else
            {
                // assembly_code.push_back("\tsubq\t$4, %rsp");
                func_buffer.var_offset-=4;
                if($3.is_const)
                {
                    //cout<<"\tmovl\t$"<<$3.value<<", "<<var_offset<<"(%rbp)"<<endl;
                    assembly_code.push_back("\tmovl\t$"+to_string($3.value)+", "+to_string(func_buffer.var_offset)+"(%rbp)");
                    var_table.back()[*$1]=Var(decl_buffer.type,$3.value,func_buffer.var_offset);
                }
                else
                {
                    // cout<<"\tmovl\t"<<$3.offset<<"(%rbp), %r8d"<<endl;
                    // cout<<"\tmovl\t%r8d, "<<var_offset<<"(%rbp)"<<endl;
                    assembly_code.push_back("\tmovl\t"+to_string($3.offset)+"(%rbp), %r8d");
                    assembly_code.push_back("\tmovl\t%r8d, "+to_string(func_buffer.var_offset)+"(%rbp)");
                    var_table.back()[*$1]=Var(decl_buffer.type,0,func_buffer.var_offset);
                }
            }
        }
        else
        {
            if(global_var_table.find(*$1)!=global_var_table.end())
            {
                cout<<"redefined variable "<<$1<<endl;
                exit(1);
            }
            else
            {
                //加入符号表
                global_var_table[*$1]=Var(decl_buffer.type,$3.value);
                assembly_code.push_back("\t.globl\t"+*$1);
                assembly_code.push_back("\t.data");
                assembly_code.push_back("\t.align\t4");
                assembly_code.push_back("\t.type\t"+*$1+", @object");
                assembly_code.push_back("\t.size\t"+*$1+", 4");
                assembly_code.push_back(*$1+":");
                assembly_code.push_back("\t.long\t"+to_string($3.value));
            }
        }
    }
    | IDENT ConstArrList
    {
        if(decl_buffer.is_global==false)
        {
            //查找是否已经定义过
            if(var_table.back().find(*$1)!=var_table.back().end())
            {
                cout<<"redefined variable "<<$1<<endl;
                exit(1);
            }
            else
            {
                //加入符号表
                Var arr_var=Var(Arr,array_dim_buffer);
                int size=1;
                for(int i=0;i<array_dim_buffer.size();i++)
                {
                    size*=array_dim_buffer[i];
                }
                func_buffer.var_offset-=size*4;
                arr_var.addr=to_string(func_buffer.var_offset)+"(%rbp)";
                var_table.back()[*$1]=arr_var;
            }
        }
        else
        {
            if(global_var_table.find(*$1)!=global_var_table.end())
            {
                cout<<"redefined variable "<<$1<<endl;
                exit(1);
            }
            else
            {
                //加入符号表
                Var arr_var=Var(Arr,array_dim_buffer);
                int size=1;
                for(int i=0;i<array_dim_buffer.size();i++)
                {
                    size*=array_dim_buffer[i];
                }
                arr_var.addr=*$1+"(%rip)";
                global_var_table[*$1]=arr_var;
                assembly_code.push_back("\t.globl\t"+*$1);
                assembly_code.push_back("\t.data");
                assembly_code.push_back("\t.align\t4");
                assembly_code.push_back("\t.type\t"+*$1+", @object");
                assembly_code.push_back("\t.size\t"+*$1+", "+to_string(size*4));
                assembly_code.push_back(*$1+":");
                assembly_code.push_back("\t.zero\t"+to_string(size*4));
            }
        }
        array_dim_buffer.clear();
    }
    | IDENT ConstArrList '=' ArrStructInit ConstInitVal
    {

        if(decl_buffer.is_global==false)
        {
            //查找是否已经定义过
            if(var_table.back().find(*$1)!=var_table.back().end())
            {
                cout<<"redefined variable "<<$1<<endl;
                exit(1);
            }
            else
            {
                //加入符号表
                Var arr_var=Var(Arr,array_dim_buffer);
                int size=array_item_buffer.size();
                func_buffer.var_offset-=size*4;
                for(int i=0;i<size;i++)
                {
                    assembly_code.push_back("\tmovl\t$"+to_string(array_item_buffer[i])+", "+to_string(func_buffer.var_offset+i*4)+"(%rbp)");
                }
                arr_var.addr=to_string(func_buffer.var_offset)+"(%rbp)";
                var_table.back()[*$1]=arr_var;
            }
        }
        else
        {
            if(global_var_table.find(*$1)!=global_var_table.end())
            {
                cout<<"redefined variable "<<$1<<endl;
                exit(1);
            }
            else
            {
                //加入符号表
                Var arr_var=Var(Arr,array_dim_buffer);
                int i;
                arr_var.addr=*$1+"(%rip)";
                global_var_table[*$1]=arr_var;
                assembly_code.push_back("\t.globl\t"+*$1);
                assembly_code.push_back("\t.data");
                assembly_code.push_back("\t.align\t4");
                assembly_code.push_back("\t.type\t"+*$1+", @object");
                assembly_code.push_back("\t.size\t"+*$1+", "+to_string(array_item_buffer.size()*4));
                assembly_code.push_back(*$1+":");
                for(i=0;i<array_item_buffer.size();i++)
                {
                    assembly_code.push_back("\t.long\t"+to_string(array_item_buffer[i]));
                }

            }
        }
        array_dim_buffer.clear();
        array_item_buffer.clear();
        array_struct_buffer.clear();
    }
    ;

VarDefList
    :
    /* empty */
    {

    }
    | ',' VarDef VarDefList
    {

    }
    ;
InitVal
    : Exp
    {
        $$=$1;
    }
    ;

BeforeConstDef
    :/* empty */
    {
        decl_buffer.is_const = true;
    }
    ;


ConstDefList
    :
    /* empty */
    {

    }
    | ',' ConstDef ConstDefList
    {

    }
    ;

ConstDef
    : IDENT '=' ConstExp
    {
        if(decl_buffer.is_global==false)
        {
            //查找是否已经定义过
            if(var_table.back().find(*$1)!=var_table.back().end())
            {
                cout<<"redefined variable "<<$1<<endl;
                exit(1);
            }
            else
            {
                //加入符号表
                var_table.back()[*$1]=Var(Constint,$3);
            }
        }
        else
        {
            if(global_var_table.find(*$1)!=global_var_table.end())
            {
                cout<<"redefined variable "<<$1<<endl;
                exit(1);
            }
            else
            {
                //加入符号表
                global_var_table[*$1]=Var(Constint,$3);
                assembly_code.push_back("\t.globl\t"+*$1);
                assembly_code.push_back("\t.data");
                assembly_code.push_back("\t.align\t4");
                assembly_code.push_back("\t.type\t"+*$1+", @object");
                assembly_code.push_back("\t.size\t"+*$1+", 4");
                assembly_code.push_back(*$1+":");
                assembly_code.push_back("\t.long\t"+to_string($3));
            }
        }
    }
    | IDENT ConstArrList '=' ArrStructInit ConstInitVal
    {

        if(decl_buffer.is_global==false)
        {
            //查找是否已经定义过
            if(var_table.back().find(*$1)!=var_table.back().end())
            {
                cout<<"redefined variable "<<$1<<endl;
                exit(1);
            }
            else
            {
                //加入符号表
                Var arr_var=Var(ConstArr,array_dim_buffer);
                int size=array_item_buffer.size();
                func_buffer.var_offset-=size*4;
                for(int i=0;i<size;i++)
                {
                    assembly_code.push_back("\tmovl\t$"+to_string(array_item_buffer[i])+", "+to_string(func_buffer.var_offset+i*4)+"(%rbp)");
                }
                arr_var.addr=to_string(func_buffer.var_offset)+"(%rbp)";
                var_table.back()[*$1]=arr_var;
            }
        }
        else
        {
            if(global_var_table.find(*$1)!=global_var_table.end())
            {
                cout<<"redefined variable "<<$1<<endl;
                exit(1);
            }
            else
            {
                //加入符号表
                Var arr_var=Var(ConstArr,array_dim_buffer);
                int i;
                arr_var.addr=*$1+"(%rip)";
                global_var_table[*$1]=arr_var;
                assembly_code.push_back("\t.globl\t"+*$1);
                assembly_code.push_back("\t.data");
                assembly_code.push_back("\t.align\t4");
                assembly_code.push_back("\t.type\t"+*$1+", @object");
                assembly_code.push_back("\t.size\t"+*$1+", "+to_string(array_item_buffer.size()*4));
                assembly_code.push_back(*$1+":");
                for(i=0;i<array_item_buffer.size();i++)
                {
                    assembly_code.push_back("\t.long\t"+to_string(array_item_buffer[i]));
                }

            }
        }
        array_dim_buffer.clear();
        array_item_buffer.clear();
        array_struct_buffer.clear();
    }
    ;

ArrStructInit
    : /*empty*/
    {
        reverse(array_dim_buffer.begin(),array_dim_buffer.end());
        Array init_array;
        init_array.unit_dims=array_dim_buffer;
        init_array.cnt=0;
        init_array.unit_size=1;
        for(int i=0;i<array_dim_buffer.size();i++)
        {
            init_array.unit_size*=array_dim_buffer[i];
        }
        array_struct_buffer.push_back(init_array);
    }

ConstArrList
    : '[' ConstExp ']'
    {
        if($2>0)
            array_dim_buffer.push_back($2);
        else
        {
            cout<<"array size must be positive"<<endl;
            exit(1);
        }
    }
    |  '[' ConstExp ']' ConstArrList
    {
        if($2>0)
            array_dim_buffer.push_back($2);
        else
        {
            cout<<"array size must be positive"<<endl;
            exit(1);
        }
    }
    ;


ConstInitVal
    : ConstExp
    {
        $$=$1;
        array_item_buffer.push_back($1);
        array_struct_buffer.back().cnt++;
    }
    | BeforeList '{' ConstInitValList '}' AfterList
    {
        
    }
    | BeforeList '{' '}' AfterList
    {

    }
    ;
BeforeList
    : /*empty*/
    {
        if(array_struct_buffer.back().unit_size==0)
        {
            array_struct_buffer.back().set_unit_dims();
        }
        else
        {
            while(array_struct_buffer.back().cnt%array_struct_buffer.back().unit_size)
            {
                array_item_buffer.push_back(0);
                array_struct_buffer.back().cnt++;
            }
        }
        array_struct_buffer.push_back(Array(array_struct_buffer.back().unit_dims));
    }
    ;

AfterList
    : /*empty*/
    {
        int full_cnt=1;
        for(int i=0;i<array_struct_buffer.back().dim.size();i++)
        {
            full_cnt*=array_struct_buffer.back().dim[i];
        }
        if(array_struct_buffer.back().cnt>full_cnt)
        {
            cout<<"too many initializers"<<endl;
            exit(1);
        }
        while(array_struct_buffer.back().cnt<full_cnt)
        {
            array_item_buffer.push_back(0);
            array_struct_buffer.back().cnt++;
        }
        array_struct_buffer.pop_back();
        array_struct_buffer.back().cnt+=full_cnt;
    }
    ;


ConstInitValList
    : ConstInitVal
    {

    }
    | ConstInitVal ',' ConstInitValList
    {

    }
    ;
LVal 
    : IDENT
    {
        //查找是否已经定义过,从后往前找
        bool flag=false;
        for(auto table=var_table.rbegin();table!=var_table.rend();table++)
        {
            if(table->find(*$1)!=table->end())
            {
                if(table->at(*$1).type==Constint)
                {
                    $$=Node(table->at(*$1).value,true);
                }
                else
                {
                    int offset=table->at(*$1).offset;
                    $$=Node(offset,false);
                }
                flag=true;
                break;
            }
        }
        //全局变量
        if(!flag)
        {
            if(global_var_table.find(*$1)!=global_var_table.end())
            {
                if(global_var_table[*$1].type==Constint)
                {
                    $$=Node(global_var_table[*$1].value,true);
                }
                else
                {
                    $$=Node((*$1).c_str());

                }
                flag=true;
            }
        }

        if(!flag)
        {
            cout<<"undefined variable "<<*$1<<endl;
            exit(1);
        }
    }
    | ArrName ArrList 
    {
        func_buffer.var_offset-=4;
        $$=Node(func_buffer.var_offset,false);
        $$.is_array=true;
        Var& var=var_buffer.back();
        assembly_code.push_back("\tleaq\t"+var.addr+", %rax");
        assembly_code.push_back("\tmovl\t"+to_string(var.offset)+"(%rbp), %edx");
        assembly_code.push_back("\tleaq\t(%rax, %rdx, 4), %rax");
        func_buffer.var_offset-=8;
        $$.idx_offset=func_buffer.var_offset;
        assembly_code.push_back("\tmovq\t%rax,\t"+to_string(func_buffer.var_offset)+"(%rbp)");
        assembly_code.push_back("\tmovl\t(%rax),\t%eax");
        assembly_code.push_back("\tmovl\t%eax, "+to_string($$.offset)+"(%rbp)");
        var_buffer.pop_back();
    }
    ;

ArrName
    :IDENT 
    {
        bool flag=false;
        for(auto table=var_table.rbegin();table!=var_table.rend();table++)
        {
            if(table->find(*$1)!=table->end())
            {

                    func_buffer.var_offset-=4;
                    int offset=func_buffer.var_offset;//idx的地址
                    Var& var=table->at(*$1);  
                    var.unit_size=1;
                    var.level=var.dim.size()-1;
                    var.offset=offset;
                    var_buffer.push_back(var);
                    assembly_code.push_back("\tmovl\t$0,\t"+to_string(offset)+"(%rbp)");
                flag=true;
                break;
            }
        }
        //全局变量
        if(!flag)
        {
            if(global_var_table.find(*$1)!=global_var_table.end())
            {
                    func_buffer.var_offset-=4;
                    int offset=func_buffer.var_offset;
                    Var& var=global_var_table[*$1];      
                    var.unit_size=1;
                    var.level=var.dim.size()-1;
                    var.offset=offset;
                    var_buffer.push_back(var);
                    // cout<<"//"<<var.addr<<endl;
                    // cout<<"//"<<var.offset<<endl;
                    assembly_code.push_back("\tmovl\t$0,\t"+to_string(offset)+"(%rbp)");
                flag=true;
            }
        }
        if(!flag)
        {
            cout<<"undefined variable "<<*$1<<endl;
            exit(1);
        }
    }
    ;
ArrList
    : '[' Exp ']'
    {
        Var &var=var_buffer.back();
        // cout<<"//"<<var.addr<<endl;
        // cout<<"//"<<var.offset<<endl;
        
        if($2.is_const)
        {
            //*var.offset=$2*var.unit_size+*var.offset
            assembly_code.push_back("\tmovl\t$"+to_string($2.value)+", %eax");
            assembly_code.push_back("\timull\t$"+to_string(var.unit_size)+", %eax");
            assembly_code.push_back("\taddl\t%eax, "+to_string(var.offset)+"(%rbp)");
        }
        else
        {
            assembly_code.push_back("\tmovl\t"+to_string($2.offset)+"(%rbp), %eax");
            assembly_code.push_back("\timull\t$"+to_string(var.unit_size)+", %eax");
            assembly_code.push_back("\taddl\t%eax, "+to_string(var.offset)+"(%rbp)");
        }
        var.unit_size*=var.dim[var.level];
        var.level--;
    }
    | '[' Exp ']' ArrList
    {
        Var &var=var_buffer.back();
        // cout<<"//"<<var.addr<<endl;
        // cout<<"//"<<var.offset<<endl;
        if($2.is_const)
        {
            //*var.offset=$2*var.unit_size+*var.offset
            assembly_code.push_back("\tmovl\t$"+to_string($2.value)+", %eax");
            assembly_code.push_back("\timull\t$"+to_string(var.unit_size)+", %eax");
            assembly_code.push_back("\taddl\t%eax, "+to_string(var.offset)+"(%rbp)");
        }
        else
        {
            assembly_code.push_back("\tmovl\t"+to_string($2.offset)+"(%rbp), %eax");
            assembly_code.push_back("\timull\t$"+to_string(var.unit_size)+", %eax");
            assembly_code.push_back("\taddl\t%eax, "+to_string(var.offset)+"(%rbp)");
        }
        var.unit_size*=var.dim[var.level];
        var.level--;
    }
    ;

ConstExp
    : Exp
    {
        if($1.is_const)
            $$=$1.value;
        else
        {
            cout<<"not a const expression"<<endl;
            exit(1);
        }
    }
    ;
%%

int yywrap() {
	return 1;
}

int main(int argc, char *argv[]) {
    //freopen("input.txt","r",stdin);
    assembly_code.push_back(".LC0:");
    assembly_code.push_back("\t.string\t\"%d\"");
    assembly_code.push_back(".LC1:");
    assembly_code.push_back("\t.string\t\"%d\\n\"");
    yyparse();
    output_assembly_code();
	return 0;
}
