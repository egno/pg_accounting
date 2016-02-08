--
-- PostgreSQL database dump
--

-- Dumped from database version 9.3.10
-- Dumped by pg_dump version 9.5.0

-- Started on 2016-02-03 13:22:12 NOVT

SET statement_timeout = 0;
SET lock_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SET check_function_bodies = false;
SET client_min_messages = warning;
SET row_security = off;

--
-- TOC entry 8 (class 2615 OID 37001597)
-- Name: acc; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA acc;


--
-- TOC entry 7404 (class 0 OID 0)
-- Dependencies: 8
-- Name: SCHEMA acc; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON SCHEMA acc IS 'Бухгалтерия';


SET search_path = acc, pg_catalog;

--
-- TOC entry 1862 (class 1255 OID 37001598)
-- Name: tf_acc(); Type: FUNCTION; Schema: acc; Owner: -
--

CREATE FUNCTION tf_acc() RETURNS trigger
    LANGUAGE plpgsql
    AS $$declare
	_id bigint;
	_debet_note text;
	_credit_note text;
	_sign integer;
	_amount numeric;
	_date timestamp with time zone;
begin
	_debet_note = null::text;
	_credit_note = null::text;
	_sign = 1;
	if TG_OP in ('DELETE', 'UPDATE') then 
		delete from acc.oper where table_name = TG_TABLE_NAME and entity_id = OLD.id;
	end if;
	if TG_OP in ('UPDATE', 'INSERT') then 
		case TG_TABLE_NAME 
		when 'regop_transfer' then
			if not (coalesce(NEW.amount,0) = 0) then
				_amount = NEW.amount;
				_date = NEW.operation_date;
				case NEW.reason
				when 
					'Возврат взносов на КР'
					,'Возврат средств'
					then
					_sign = 1;
					select '{"account":"Нераспределённые оплаты"}' , 
					'{"account":"Остаток начислений по ЛС", "regop_pers_acc":' || p_acc.id::text || ', "part":"Тариф Базовый"}'
					into _debet_note, _credit_note
					from regop_wallet w 
					join regop_pers_acc p_acc on ((w.id = p_acc.bt_wallet_id))
					where (NEW.source_guid = w.wallet_guid);
				when 'Оплата по базовому тарифу' then
					select
					'{"account":"Остаток начислений по ЛС", "regop_pers_acc":' ||(p_acc.id::text)|| ', "part":"Тариф Базовый"}',
					'{"account":"'
					|| case 
						when c.id is not null then 'Нераспределённые оплаты", "gkh_contragent":'||(c.id::text)||'}'
						when i.id is not null then 'Нераспределённые реестры", "regop_bank_doc_import":'||(i.id::text)||'}'
						when sa.id is not null then 'Невыясненные платежи", "regop_suspense_account":'||(sa.id::text)||'}'
					else 'Нераспределённые оплаты"}' 
					end
					into _debet_note, _credit_note
					from 
					regop_wallet w  
					join regop_pers_acc p_acc on ((w.id = p_acc.bt_wallet_id))
					left join regop_bank_acc_stmnt p on p.transfer_guid = NEW.source_guid 
					left join gkh_contragent c on c.id=payer_contragent_id or (c.inn=p.payer_inn and p.payer_inn is not null)
					left join regop_bank_doc_import i on i.transfer_guid=NEW.source_guid
					left join regop_suspense_account sa on sa.c_guid=NEW.source_guid 
					where (NEW.target_guid = w.wallet_guid)
					and not NEW.is_copy_for_source
					order by (not payer_contragent_id is null)
					limit 1
					;
				when 'Оплата по тарифу решения' then
					select
					'{"account":"Остаток начислений по ЛС", "regop_pers_acc":' ||(p_acc.id::text)|| ', "part":"Тариф Решение"}',
					'{"account":"'
					|| case 
						when c.id is not null then 'Нераспределённые оплаты", "gkh_contragent":'||(c.id::text)||'}'
						when i.id is not null then 'Нераспределённые реестры", "regop_bank_doc_import":'||(i.id::text)||'}'
						when sa.id is not null then 'Невыясненные платежи", "regop_suspense_account":'||(sa.id::text)||'}'
					else 'Нераспределённые оплаты"}' 
					end
					into _debet_note, _credit_note
					from 
					regop_wallet w 
					join regop_pers_acc p_acc on ((w.id = p_acc.dt_wallet_id))
					left join regop_bank_acc_stmnt p on p.transfer_guid = NEW.source_guid 
					left join gkh_contragent c on c.id=payer_contragent_id or (c.inn=p.payer_inn and p.payer_inn is not null)
					left join regop_bank_doc_import i on i.transfer_guid=NEW.source_guid
					left join regop_suspense_account sa on sa.c_guid=NEW.source_guid 
					where (NEW.target_guid = w.wallet_guid)
					and not NEW.is_copy_for_source
					order by (not payer_contragent_id is null)
					limit 1
					;
				when 'Оплата пени' then
					select
					'{"account":"Остаток начислений по ЛС", "regop_pers_acc":' ||(p_acc.id::text)|| ', "part":"Пеня"}',
					'{"account":"'
					|| case 
						when c.id is not null then 'Нераспределённые оплаты", "gkh_contragent":'||(c.id::text)||'}'
						when i.id is not null then 'Нераспределённые реестры", "regop_bank_doc_import":'||(i.id::text)||'}'
						when sa.id is not null then 'Невыясненные платежи", "regop_suspense_account":'||(sa.id::text)||'}'
					else 'Нераспределённые оплаты"}' 
					end
					into _debet_note, _credit_note
					from 
					regop_wallet w 
					join regop_pers_acc p_acc on ((w.id = p_acc.p_wallet_id))
					left join regop_bank_acc_stmnt p on p.transfer_guid = NEW.source_guid 
					left join gkh_contragent c on c.id=payer_contragent_id or (c.inn=p.payer_inn and p.payer_inn is not null)
					left join regop_bank_doc_import i on i.transfer_guid=NEW.source_guid
					left join regop_suspense_account sa on sa.c_guid=NEW.source_guid 
					where (NEW.target_guid = w.wallet_guid)
					and not NEW.is_copy_for_source
					order by (not payer_contragent_id is null)
					limit 1
					;
				when 'Отмена оплаты по базовому тарифу' then
					_sign = -1;
					select '{"account":"Остаток начислений по ЛС", "regop_pers_acc":' ||(p_acc.id::text)|| ', "part":"Тариф Базовый"}',
					'{"account":"Нераспределённые оплаты"}'
					into _debet_note, _credit_note
					from regop_wallet w 
					join regop_pers_acc p_acc on ((w.id = p_acc.bt_wallet_id))
					where (NEW.source_guid = w.wallet_guid);
				when 'Отмена оплаты по тарифу решения' then
					_sign = -1;
					select '{"account":"Остаток начислений по ЛС", "regop_pers_acc":' ||(p_acc.id::text)|| ', "part":"Тариф Решение"}',
					'{"account":"Нераспределённые оплаты"}'
					into _debet_note, _credit_note
					from regop_wallet w 
					join regop_pers_acc p_acc on ((w.id = p_acc.dt_wallet_id))
					where (NEW.source_guid = w.wallet_guid);
				when 'Отмена оплаты пени' then
					_sign = -1;
					select '{"account":"Остаток начислений по ЛС", "regop_pers_acc":' ||(p_acc.id::text)|| ', "part":"Пеня"}',
					'{"account":"Нераспределённые оплаты"}'
					into _debet_note, _credit_note
					from regop_wallet w 
					join regop_pers_acc p_acc on ((w.id = p_acc.p_wallet_id))
					where (NEW.source_guid = w.wallet_guid);
				else
					--RAISE NOTICE 'Reason "%" from %=% was not found', NEW.reason, TG_TABLE_NAME, NEW.id;
				end case;
				insert into acc.oper (dt, sm,  
					debet_descr, credit_descr,
					table_name, entity_id,
					notes) 
				select 
				_date,
				_amount * _sign,
				
				_debet_note::json,
				_credit_note::json,
				TG_TABLE_NAME,
				NEW.id,
				NEW.reason
				from unnest(array[1])
				
				returning id into _id;
			end if;

		when 'regop_pers_acc_period_summ' then
                        if not (NEW.charge_tariff = 0) then
				insert into acc.oper (dt, sm, 
		                        debet_descr, credit_descr,
		                        table_name, entity_id,
		                        notes) 
		                select 
		                coalesce(p.cend,now()),
		                NEW.charge_tariff,
		                ('{"account":"Невыставленные начисления", "regop_pers_acc":' || NEW.account_id::text || ', "part":"Тариф"}')::json, 
		                ('{"account":"Остаток начислений по ЛС", "regop_pers_acc":' || NEW.account_id::text || ', "part":"Тариф"}')::json, 
		                TG_TABLE_NAME,
		                NEW.id,
		                'Начисление'
		                from unnest(array[1])
		                left join regop_period p on p.id=NEW.period_id
		                returning id into _id;
			end if;

                        if not (NEW.penalty = 0) then
		                insert into acc.oper (dt, sm, 
		                        debet_descr, credit_descr,
		                        table_name, entity_id,
		                        notes) 
		                select 
		                coalesce(p.cend,now()),
		                NEW.penalty,
		                ('{"account":"Невыставленные начисления", "regop_pers_acc":' || NEW.account_id::text || ', "part":"Пеня"}')::json, 
		                ('{"account":"Остаток начислений по ЛС", "regop_pers_acc":' || NEW.account_id::text || ', "part":"Пеня"}')::json, 
		                TG_TABLE_NAME,
		                NEW.id,
		                'Начисление пени'
		                from unnest(array[1])
		                left join regop_period p on p.id=NEW.period_id
		                returning id into _id;
			end if;

                        if not (NEW.recalc = 0) then
		                insert into acc.oper (dt, sm, 
		                        debet_descr, credit_descr,
		                        table_name, entity_id,
		                        notes) 
		                select 
		                coalesce(p.cend,now()),
		                NEW.recalc,
		                ('{"account":"Невыставленные начисления", "regop_pers_acc":' || NEW.account_id::text || ', "part":"Тариф"}')::json, 
		                ('{"account":"Остаток начислений по ЛС", "regop_pers_acc":' || NEW.account_id::text || ', "part":"Тариф"}')::json, 
		                TG_TABLE_NAME,
		                NEW.id,
		                'Перерасчёт'
		                from unnest(array[1])
		                left join regop_period p on p.id=NEW.period_id
		                returning id into _id;
			end if;

                        if not (NEW.recalc_penalty = 0) then
		                insert into acc.oper (dt, sm, 
		                        debet_descr, credit_descr,
		                        table_name, entity_id,
		                        notes) 
		                select 
		                coalesce(p.cend,now()),
		                NEW.recalc_penalty,
		                ('{"account":"Невыставленные начисления", "regop_pers_acc":' || NEW.account_id::text || ', "part":"Тариф"}')::json, 
		                ('{"account":"Остаток начислений по ЛС", "regop_pers_acc":' || NEW.account_id::text || ', "part":"Тариф"}')::json, 
		                TG_TABLE_NAME,
		                NEW.id,
		                'Перерасчёт пени'
		                from unnest(array[1])
		                left join regop_period p on p.id=NEW.period_id
		                returning id into _id;
			end if;

                        if not (NEW.recalc_decision = 0) then
		                insert into acc.oper (dt, sm, 
		                        debet_descr, credit_descr,
		                        table_name, entity_id,
		                        notes) 
		                select 
		                coalesce(p.cend,now()),
		                NEW.recalc_decision,
		                ('{"account":"Невыставленные начисления", "regop_pers_acc":' || NEW.account_id::text || ', "part":"Тариф"}')::json, 
		                ('{"account":"Остаток начислений по ЛС", "regop_pers_acc":' || NEW.account_id::text || ', "part":"Тариф"}')::json, 
		                TG_TABLE_NAME,
		                NEW.id,
		                'Перерасчёт по тарифу решения'
		                from unnest(array[1])
		                left join regop_period p on p.id=NEW.period_id
		                returning id into _id;
			end if;
                        
			
		when 'regop_payment_doc_snapshot' then
			_amount = NEW.total_payment;
			_date = coalesce(NEW.doc_date, NEW.object_edit_date);
			select '{"account":"Расчёты с абонентами"'||coalesce(coalesce(', "gkh_contragent":'||c.id, ', "regop_individual_acc_own":'||ia.id),'') ||'}',
			'{"account":"Невыставленные начисления"}'
			into _debet_note, _credit_note			
			from unnest(array[1])
			left join regop_pers_acc_owner pa on pa.id = NEW.holder_id and NEW.holder_type='AccountOwner'
			left join regop_legal_acc_own lo on lo.id=pa.id and NEW.holder_type='AccountOwner'
			left join regop_pers_acc a on a.id=NEW.holder_id and NEW.holder_type='PersonalAccount' 
			left join gkh_contragent c on c.id = lo.contragent_id
			left join (
				select distinct on (1)
				acc_id,
				old_value
				from 
				regop_pers_acc_change
				where 
				"date" > NEW.object_edit_date
				and change_type=4
				
				order by 1, date 
			) ha on ha.acc_id=a.id	
			left join regop_individual_acc_own ia on ia.id=coalesce(old_value::bigint, a.acc_owner_id)
			;

/*
-- детализация счёта по ЛС не имеет смысла, т.к. к оплате может быть выставлена сумма не равная сумме начислений по ЛС
-- например, если раннее получилась пререплата в результате перерасчёта, то в этом месяце к оплате выставляется сумма с учётом этой переплаты.

			if exists (select 'x' from regop_pers_paydoc_snap where snapshot_id=NEW.id) then
				insert into acc.oper ( dt, sm , 
					debet_descr, credit_descr,
					table_name, entity_id,
					notes) 
				select 
				_date,
				ds.base_tariff_sum * _sign,
				_debet_note::json,
				('{"account":"Невыставленные начисления", "regop_pers_acc":' || coalesce(ds.account_id,0)::text || ', "part":"Тариф Базовый"}')::json,
				TG_TABLE_NAME,
				NEW.id,
				'Выставлен счёт на оплату'
				from regop_pers_paydoc_snap ds 
				where ds.snapshot_id=NEW.id
				and not coalesce(ds.base_tariff_sum,0) = 0;

				insert into acc.oper ( dt, sm , 
					debet_descr, credit_descr,
					table_name, entity_id,
					notes) 
				select 
				_date,
				ds.dec_tariff_sum * _sign,
				_debet_note::json,
				('{"account":"Невыставленные начисления", "regop_pers_acc":' || coalesce(ds.account_id,0)::text || ', "part":"Тариф Решение"}')::json,
				TG_TABLE_NAME,
				NEW.id,
				'Выставлен счёт на оплату'
				from regop_pers_paydoc_snap ds 
				where ds.snapshot_id=NEW.id
				and not coalesce(ds.dec_tariff_sum,0) = 0;

				insert into acc.oper ( dt, sm , 
					debet_descr, credit_descr,
					table_name, entity_id,
					notes) 
				select 
				_date,
				ds.penalty_sum * _sign,
				_debet_note::json,
				('{"account":"Невыставленные начисления", "regop_pers_acc":' || coalesce(ds.account_id,0)::text || ', "part":"Пеня"}')::json,
				TG_TABLE_NAME,
				NEW.id,
				'Выставлен счёт на оплату'
				from regop_pers_paydoc_snap ds 
				where ds.snapshot_id=NEW.id
				and not coalesce(ds.penalty_sum,0) = 0;
			else
*/			
				insert into acc.oper ( dt, sm , 
					debet_descr, credit_descr,
					table_name, entity_id,
					notes) 
				select 
				_date,
				_amount * _sign,
				_debet_note::json,
				_credit_note::json,
				TG_TABLE_NAME,
				NEW.id,
				'Выставлен счёт на оплату'
				from unnest(array[1])
				returning id into _id;
--			end if;

		else
			RAISE NOTICE 'Record %=% was skipped', TG_TABLE_NAME, NEW.id;
		end case;

	end if;
	return null;
end;$$;


SET default_with_oids = false;

--
-- TOC entry 1754 (class 1259 OID 37001600)
-- Name: oper; Type: TABLE; Schema: acc; Owner: -
--

CREATE TABLE oper (
    id bigint NOT NULL,
    dt timestamp with time zone DEFAULT now() NOT NULL,
    ts timestamp with time zone DEFAULT now(),
    notes character varying,
    sm numeric,
    debet_notes character varying,
    credit_notes character varying,
    table_name name,
    entity_id bigint,
    debet_descr json,
    credit_descr json
);


--
-- TOC entry 7405 (class 0 OID 0)
-- Dependencies: 1754
-- Name: TABLE oper; Type: COMMENT; Schema: acc; Owner: -
--

COMMENT ON TABLE oper IS 'Журнал операций';


--
-- TOC entry 7406 (class 0 OID 0)
-- Dependencies: 1754
-- Name: COLUMN oper.dt; Type: COMMENT; Schema: acc; Owner: -
--

COMMENT ON COLUMN oper.dt IS 'Дата, за которую нужно учесть операцию';


--
-- TOC entry 7407 (class 0 OID 0)
-- Dependencies: 1754
-- Name: COLUMN oper.ts; Type: COMMENT; Schema: acc; Owner: -
--

COMMENT ON COLUMN oper.ts IS 'Дата и время фактический записи в журнал операций';


--
-- TOC entry 7408 (class 0 OID 0)
-- Dependencies: 1754
-- Name: COLUMN oper.notes; Type: COMMENT; Schema: acc; Owner: -
--

COMMENT ON COLUMN oper.notes IS 'Описание операции';


--
-- TOC entry 7409 (class 0 OID 0)
-- Dependencies: 1754
-- Name: COLUMN oper.sm; Type: COMMENT; Schema: acc; Owner: -
--

COMMENT ON COLUMN oper.sm IS 'Сумма операции';


--
-- TOC entry 1755 (class 1259 OID 37001608)
-- Name: oper_id_seq; Type: SEQUENCE; Schema: acc; Owner: -
--

CREATE SEQUENCE oper_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 7410 (class 0 OID 0)
-- Dependencies: 1755
-- Name: oper_id_seq; Type: SEQUENCE OWNED BY; Schema: acc; Owner: -
--

ALTER SEQUENCE oper_id_seq OWNED BY oper.id;


--
-- TOC entry 7234 (class 2604 OID 37001610)
-- Name: id; Type: DEFAULT; Schema: acc; Owner: -
--

ALTER TABLE ONLY oper ALTER COLUMN id SET DEFAULT nextval('oper_id_seq'::regclass);


--
-- TOC entry 7245 (class 2606 OID 37001612)
-- Name: pk_oper; Type: CONSTRAINT; Schema: acc; Owner: -
--

ALTER TABLE ONLY oper
    ADD CONSTRAINT pk_oper PRIMARY KEY (id);


--
-- TOC entry 7237 (class 1259 OID 37001613)
-- Name: idx_dt; Type: INDEX; Schema: acc; Owner: -
--

CREATE INDEX idx_dt ON oper USING btree (dt);


--
-- TOC entry 7238 (class 1259 OID 37001614)
-- Name: idx_oper_c; Type: INDEX; Schema: acc; Owner: -
--

CREATE INDEX idx_oper_c ON oper USING btree (((credit_descr ->> 'regop_pers_acc'::text)));


--
-- TOC entry 7239 (class 1259 OID 37013309)
-- Name: idx_oper_cacc; Type: INDEX; Schema: acc; Owner: -
--

CREATE INDEX idx_oper_cacc ON oper USING btree (((credit_descr ->> 'account'::text)));


--
-- TOC entry 7240 (class 1259 OID 42312088)
-- Name: idx_oper_cca; Type: INDEX; Schema: acc; Owner: -
--

CREATE INDEX idx_oper_cca ON oper USING btree (((credit_descr ->> 'gkh_contragent'::text)));


--
-- TOC entry 7241 (class 1259 OID 37001615)
-- Name: idx_oper_d; Type: INDEX; Schema: acc; Owner: -
--

CREATE INDEX idx_oper_d ON oper USING btree (((debet_descr ->> 'regop_pers_acc'::text)));


--
-- TOC entry 7242 (class 1259 OID 37013310)
-- Name: idx_oper_dacc; Type: INDEX; Schema: acc; Owner: -
--

CREATE INDEX idx_oper_dacc ON oper USING btree (((debet_descr ->> 'account'::text)));


--
-- TOC entry 7243 (class 1259 OID 37001616)
-- Name: idx_oper_table_id; Type: INDEX; Schema: acc; Owner: -
--

CREATE INDEX idx_oper_table_id ON oper USING btree (table_name, entity_id);


-- Completed on 2016-02-03 13:22:29 NOVT

--
-- PostgreSQL database dump complete
--

