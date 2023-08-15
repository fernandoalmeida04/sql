IF EXISTS (SELECT name 
	   FROM   sysobjects 
	   WHERE  name = N'pr_extracao_dados_pedido_compra' 
	   AND 	  type = 'P')
    DROP PROCEDURE pr_extracao_dados_pedido_compra

go
--pedido_compra
-------------------------------------------------------------------------------
--sp_helptext pr_extracao_dados_pedido_compra
-------------------------------------------------------------------------------
--pr_extracao_dados_pedido_compra
-------------------------------------------------------------------------------
--Stored Procedure : Microsoft SQL Server 2000
--Autor(es)        : Fernando Almeida
--                   
--
--Banco de Dados   : Egissql
--
--Objetivo         : Extração dos Dados Pedido de Compra para Geração 
--                   do Relatório via Word
--Data             : 18.04.2019
--Alteração        : 

------------------------------------------------------------------------------
create procedure pr_extracao_dados_pedido_compra
@cd_parametro   					int = 0,  	  --> 1. Dados / 2. Itens
@cd_pedido_compra  					int = 0,
@cd_modelo							int = 0, 	  --> 0. Modelo Padrão
@cd_usuario							int = 0			

as

declare @dt_hoje            datetime 
declare @nm_caminho         varchar(150) 
declare @nm_caminho_gerado  varchar(150) 
declare @cd_empresa         int

set @cd_empresa        = dbo.fn_empresa()
set @nm_caminho        = 'C:\FER-PC\PedidoCompra\'
set @nm_caminho_gerado = 'C:\FER-PC\PedidoCompra\Geradas\'
set @dt_hoje           = convert(datetime,left(convert(varchar,getdate(),121),10)+' 00:00:00',121)


/************************
  Itens do Pedido Compra
************************/
declare
  @ic_desconto char(1)

set @ic_desconto= (select isnull(ic_desconto_item_pedido,'N')
	from Parametro_Pedido_Compra with (nolock) 
    where cd_empresa = @cd_empresa)

select 
	i.cd_pedido_compra                             as cd_pedido_compra,
	i.cd_item_pedido_compra                        as CD_ITEM,
	( case 
      when ( IsNull(i.nm_fantasia_produto, isNull(s.nm_servico,'')) = '' ) or ( IsNull(fp.nm_produto_fornecedor,'') <> '' ) then
         ''       
      else 
        IsNull(i.nm_fantasia_produto, isNull(s.nm_servico,'')) 
   end )  										   as FANTASIA,
	i.nm_produto                                   as NM_PROD,
  i.nm_marca_item_pedido						   as MARCA,
  (select sg_unidade_medida from Unidade_medida where i.cd_unidade_medida = cd_unidade_medida) as 'SG_UNID',
  i.dt_entrega_item_ped_compr                      as DT_ENTR,
  case when isnull(um.ic_fator_conversao,'P') = 'K'
  then
   	case when isnull(i.qt_item_pesbr_ped_compra,0) >0 
    then
      i.qt_item_pesbr_ped_compra    
    else
      i.qt_item_pedido_compra
    end
  else
     isnull(i.qt_item_pedido_compra,0) 
  end 											   as QT_ITEM,
	i.qt_saldo_item_ped_compra                     as QT_SALDO,
	case when @ic_desconto='S' then
    i.vl_item_unitario_ped_comp
    else
    i.vl_item_unitario_ped_comp-
    isnull((i.vl_item_unitario_ped_comp*( isnull(pc_item_descto_ped_compra,0)/100)),0) end as VL_ITEM,
  i.vl_total_item_pedido_comp                      as VL_TOT,
  isnull(pc.vl_total_pedido_ipi,0.00)              as vl_total_ipi_pedido,
	isnull(pc.vl_total_pedido_ipi,0.00)+isnull(i.vl_total_item_pedido_comp,0.00)  as vl_total_com_ipi,
	isnull(pc.vl_total_pedido_compra,0.00) 		   as vl_total_pedido_compra,
	isnull(i.vl_desconto_item_pedido,0.00)         as vl_desconto_pedido_compra
into 
	#Itens

from 
  pedido_compra_item i
  left outer join Pedido_Compra pc               on pc.cd_pedido_compra  = i.cd_pedido_Compra 
  left outer join Servico s                      on s.cd_servico         = i.cd_servico
  left outer join Fornecedor_Produto fp          on fp.cd_fornecedor     = pc.cd_fornecedor and fp.cd_produto = i.cd_produto
  left outer join Unidade_Medida um              on um.cd_unidade_medida = i.cd_unidade_medida

/********************
	Totais dos Itens
********************/
select 
  it.cd_pedido_compra,
	sum(isnull(it.vl_total_pedido_compra,0.00) + isnull(it.vl_desconto_pedido_compra,0.00)) as vl_total_pedido_compra,
  sum(isnull(it.vl_total_ipi_pedido,0.00))                 									as vl_total_ipi_pedido,
 	sum(isnull(it.vl_total_com_ipi,0.00))                 									as vl_total_com_ipi

	
into
	#TotalItens

from 
	#Itens it

group by 
	cd_pedido_compra




/******************************
  Dados do Pedido de Compra
******************************/
if @cd_parametro = 0
begin

	declare @ds_msg_rodape    varchar(500)
	
	select
		@ds_msg_rodape = cast(ds_msg_rodape_pedido as varchar(500))
	from
		parametro_suprimento
	where
		cd_empresa = @cd_empresa
		

	select 
		pc.cd_pedido_compra     								as cd_pedido_compra,
		pc.dt_pedido_compra                                     as dt_pedido_compra,
		dq.cd_identificacao_documento                           as cd_identificacao_documento,
		sp.sg_status_pedido                                     as sg_status_pedido,
    	-- Dados da Empresa --------------------------------------------------------
    	isnull(vwe.nm_empresa,'')                             	as NM_EMPRESA,
    	isnull(vwe.cd_telefone_empresa,'')                    	as TELEFONE_EMPRESA,
    	isnull(vwe.Endereco_Empresa,'')                       	as ENDERECO_EMPRESA,
    	isnull(vwe.nm_email_internet,'')                      	as EMAIL_EMPRESA,
    	isnull(vwe.nm_dominio_internet,'')                    	as SITE_EMPRESA,
		isnull(vwe.cnpj,'')										as CNPJ_EMPRESA,
		isnull(vwe.cd_iest_empresa,'')							as IE_EMPRESA,
		isnull(ee.nm_local_entrega_empresa,'')                  as nm_local_entrega,
		-- Dados do Fornecedor -----------------------------------------------------
		fo.nm_razao_social 										as nm_razao_social_fornecedor,        
  		fo.nm_fantasia_fornecedor 								as nm_fantasia_fornecedor,
		pc.nm_ref_pedido_compra 								as nm_ref_pedido_compra, 
		IsNull(tp.ic_pedido_mat_prima,'N')                      as 'ic_pedido_mat_prima',
  		case when isnull(co.cd_fax_contato_fornecedor,'') <> '' then
    		co.cd_fax_contato_fornecedor
  		else 
    		fo.cd_fax end                                       as cd_fax_fornecedor,                      
  		case when isnull(co.cd_telefone_contato_forne,'')<>'' then
    		co.cd_telefone_contato_forne 
  		else
    		fo.cd_telefone end                					as cd_telefone_fornecedor,           
   		case when isnull(co.cd_ddd_contato_fornecedor,'')<>'' then
    		co.cd_ddd_contato_fornecedor
  		else
    		fo.cd_ddd end										as cd_ddd_fornecedor, 
  		fo.cd_fornecedor 										as cd_fornecedor,                  
  		IsNull(RTrim(LTrim(fo.nm_endereco_fornecedor)) + ',','')+
    	IsNull(RTrim(LTrim(fo.cd_numero_endereco)) + ' - ','')+
    	IsNull(RTrim(LTrim(fo.nm_bairro)) + ' - ','')+
    	IsNull(RTrim(LTrim(cf.nm_cidade)) + '/','')+
    	IsNull(RTrim(LTrim(ef.sg_estado)) + ' - ','') 			as 'nm_endereco_fornecedor',
  		fo.cd_cnpj_fornecedor,
  		case when isnull(co.cd_email_contato_forneced,'')<>'' then
   			co.cd_email_contato_forneced
  		else
    		fo.nm_email_fornecedor end							as nm_email_fornecedor,
  		fo.cd_inscmunicipal      								as cd_inscmunicipal_fornecedor,
  		fo.cd_inscestadual       								as cd_inscestadual_fornecedor,
		pc.nm_pedfornec_pedido_compr                            as nm_pedfornec_pedido_compr,
		@dt_hoje                                                as dt_hoje,
  	
		-- Dados da Transportadora --------------------------------------------------
		tr.nm_transportadora 									as nm_transportadora,
  		IsNull(RTrim(LTrim(tr.nm_endereco)) + ',','')+
    	IsNull(RTrim(LTrim(tr.cd_numero_endereco)) + ' - ','')+
    	IsNull(RTrim(LTrim(tr.nm_bairro)) + ' - ','')+
    	IsNull(RTrim(LTrim(ct.nm_cidade)) + '/','')+
    	IsNull(RTrim(LTrim(et.sg_estado)) + ' - ','')+
    	IsNull(RTrim(LTrim(tr.cd_cep)),'') 				   	    as 'nm_endereco_transp',
  		fo.cd_cep 												as cd_cep,
		pc.cd_contato_fornecedor 								as cd_contato_fornecedor,
  		tr.cd_ddd                            					as cd_ddd_transp,
  		tr.cd_telefone                       					as cd_telefone_transp,
  		tr.nm_email_transportadora 								as nm_email_transportadora,
		
		-- Dados Pedido de Compra ----------------------------------------------------
		pc.nm_ref_pedido_compra             					as nm_ref_pedido_compra,
		pc.nm_pedfornec_pedido_compr							as nm_pedfornec_pedido_compra,
		co.nm_fantasia_contato_forne                            as nm_fantasia_contato_forne,
		co.cd_ddd_contato_fornecedor							as cd_ddd_contato_fornecedor,
		co.cd_telefone_contato_forne							as cd_telefone_contato_forne,
		co.cd_fax_contato_fornecedor                            as cd_fax_contato_fornecedor,
		cp.nm_condicao_pagamento								as nm_condicao_pagamento,
		pc.dt_nec_pedido_compra									as dt_nec_pedido_compra,
		ap.nm_aplicacao_produto									as nm_aplicacao_produto,
		de.nm_destinacao_produto                                as nm_destinacao_produto,
		cc.nm_centro_custo                                      as nm_centro_custo, 
		cc.cd_centro_custo										as cd_centro_custo,
		
		-- Dados do Solicitante ------------------------------------------------------
		(Select top 1 nm_fantasia_usuario 
  		from EGISADMIN.dbo.Usuario u inner join  
          Requisicao_Compra rc with (NOLOCK) on rc.cd_requisitante = u.cd_usuario inner join
          Requisicao_Compra_item rci with (NOLOCK) on rci.cd_requisicao_compra = rc.cd_requisicao_compra
  	    where rci.cd_pedido_compra = pc.cd_pedido_compra )  	as 'nm_solicitante',
		dep.nm_departamento                                     as nm_departamento,
		plc.cd_mascara_plano_compra + ' - ' + plc.nm_plano_compra as 'cd_mascara_plano_compra',
		cm.nm_fantasia_comprador                                as nm_fantasia_comprador,
		isnull(pc.vl_icms_st,0)                                 as vl_icms_st,
		isnull(pc.vl_frete_pedido_compra,0.00)                  as vl_frete_pedido_compra,
		isnull(pc.vl_desconto_pedido_compra,0.00) 				as vl_desconto_pedido_compra,

		-- Dados do Pedido -----------------------------------------------------------
		pc.ds_pedido_compra                                     as ds_pedido_compra,
  	    te.nm_tipo_entrega_produto                              as nm_tipo_entrega_produto,
  	    pc.dt_conf_pedido_compra								as dt_conf_pedido_compra,
		pc.nm_conf_pedido_compra								as nm_conf_pedido_compra,
	    pc.dt_cancel_ped_compra									as dt_cancel_ped_compra,
		cast(pc.ds_ativacao_pedido_compra as varchar(256))      as ds_ativacao_pedido_compra,
	    pc.dt_alteracao_ped_compra								as dt_alteracao_ped_compra,
	    tap.nm_tipo_alteracao_pedido + '-' + pc.ds_alteracao_ped_compra as ds_alteracao_ped_compra,
		@ds_msg_rodape                                          as msg_rodape,		
    	-- Totais dos Itens ----------------------------------------------------------
		ti.vl_total_pedido_compra                               as VL_TOT_PED,
		ti.vl_total_ipi_pedido                                  as VL_TOT_IPI,
		ti.vl_total_com_ipi                                     as VL_TCOM_IPI,
		((pc.vl_total_pedido_compra + pc.vl_frete_pedido_compra 
		+ pc.vl_total_ipi_pedido) * pc.pc_custofin_pedido_compra) / 100 as VL_CUSTO_FIN
		
	from 
		pedido_Compra pc
		left outer join vw_empresa_endereco vwe   	           on vwe.cd_empresa   			   = @cd_empresa
		left outer join fornecedor fo                          on fo.cd_fornecedor             = pc.cd_fornecedor
		left outer join fornecedor_contato co                  on co.cd_fornecedor             = pc.cd_fornecedor and co.cd_contato_fornecedor     = pc.cd_contato_fornecedor
		left outer join cidade cf                              on cf.cd_cidade                 = fo.cd_cidade
		left outer join estado ef                              on ef.cd_estado				   = fo.cd_estado
		left outer join transportadora tr                      on tr.cd_transportadora         = pc.cd_transportadora
		left outer join cidade ct       					   on ct.cd_cidade				   = tr.cd_cidade
		left outer join estado et                              on et.cd_estado				   = tr.cd_estado
		left outer join tipo_pedido tp                         on tp.cd_tipo_pedido 		   = pc.cd_tipo_pedido
		left outer join condicao_pagamento cp				   on cp.cd_condicao_pagamento	   = pc.cd_condicao_pagamento
		left outer join aplicacao_produto ap                   on ap.cd_aplicacao_produto      = pc.cd_aplicacao_produto
		left outer join destinacao_produto de                  on de.cd_destinacao_produto 	   = pc.cd_destinacao_produto
		left outer join Centro_Custo cc                        on cc.cd_centro_custo           = pc.cd_centro_custo
		left outer join dbo.Departamento dep    			   on dep.cd_departamento          = pc.cd_departamento
		left outer join Plano_Compra plc					   on pc.cd_plano_compra           = plc.cd_plano_compra
		left outer join comprador cm                           on pc.cd_comprador              = cm.cd_comprador
		left outer join	tipo_entrega_produto te                on pc.cd_tipo_entrega_produto   = te.cd_tipo_entrega_produto
		left outer join Tipo_Alteracao_Pedido tap 			   on tap.cd_tipo_alteracao_pedido = pc.cd_tipo_alteracao_pedido 
		left outer join #TotalItens ti                         on ti.cd_pedido_compra          = pc.cd_pedido_compra
		left outer join parametro_pedido_compra ppc			   on ppc.cd_empresa               = @cd_empresa
		left outer join documento_qualidade dq                 on dq.cd_documento_qualidade    = ppc.cd_documento_qualidade
		left outer join status_pedido sp                       on sp.cd_status_pedido          = pc.cd_status_pedido
		left outer join empresa_entrega ee                     on ee.cd_empresa                = @cd_empresa
	where pc.cd_pedido_compra = @cd_pedido_compra
end

if @cd_parametro = 1
	if @cd_modelo = 0
		begin
			select
				it.CD_ITEM, it.FANTASIA, it.NM_PROD, it.MARCA, it.SG_UNID, it.DT_ENTR, it.QT_ITEM, it.QT_SALDO, it.VL_ITEM, it.VL_TOT
		from #Itens it
		where it.cd_pedido_compra = @cd_pedido_compra
		end
	if @cd_modelo = 1
		begin
			select
				it.CD_ITEM, it.NM_PROD, it.cd_pedido_compra, it.QT_ITEM, it.VL_ITEM, it.VL_TOT, it.DT_ENTR
		from #Itens it
		where it.cd_pedido_compra = @cd_pedido_compra
		end
go
/*-------------------------------------------------------------------------------------------
Testando a procedure
---------------------------------------------------------------------------------------------
exec pr_extracao_dados_pedido_compra 1,202383
-------------------------------------------------------------------------------------------*/
