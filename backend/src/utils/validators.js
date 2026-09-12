/**
 * Helpers de validacao e normalizacao de parametros da API.
 * Mantidos sem dependencia externa para facilitar a leitura do projeto.
 */
'use strict';

const AppError = require('./AppError');

/** Converte para inteiro positivo ou lanca 400. */
function parseId(value, fieldName) {
  const parsed = Number.parseInt(value, 10);
  if (Number.isNaN(parsed) || parsed <= 0) {
    throw AppError.badRequest(`O campo "${fieldName}" deve ser um inteiro positivo.`);
  }
  return parsed;
}

/**
 * Converte para inteiro >= 0, aceitando ausencia (devolve 0).
 *
 * Usado pelo cursor `depoisDoId` do chat: 0 significa "desde o inicio da
 * conversa", valor legitimo quando o aplicativo ainda nao tem nenhuma
 * mensagem carregada.
 */
function parseCursor(value, fieldName) {
  if (value === undefined || value === null || value === '') return 0;
  const parsed = Number.parseInt(value, 10);
  if (Number.isNaN(parsed) || parsed < 0) {
    throw AppError.badRequest(
      `O campo "${fieldName}" deve ser um inteiro maior ou igual a zero.`,
    );
  }
  return parsed;
}

/** Converte para numero dentro de um intervalo ou lanca 400. */
function parseNumber(value, fieldName, { min, max }) {
  const parsed = typeof value === 'number' ? value : Number.parseFloat(value);
  if (Number.isNaN(parsed)) {
    throw AppError.badRequest(`O campo "${fieldName}" deve ser numerico.`);
  }
  if (parsed < min || parsed > max) {
    throw AppError.badRequest(
      `O campo "${fieldName}" deve estar entre ${min} e ${max}.`,
    );
  }
  return parsed;
}

/** Valida texto obrigatorio, aplicando trim e limite de tamanho. */
function parseText(value, fieldName, maxLength) {
  if (typeof value !== 'string') {
    throw AppError.badRequest(`O campo "${fieldName}" e obrigatorio.`);
  }
  const trimmed = value.trim();
  if (trimmed.length === 0) {
    throw AppError.badRequest(`O campo "${fieldName}" nao pode ser vazio.`);
  }
  if (trimmed.length > maxLength) {
    throw AppError.badRequest(
      `O campo "${fieldName}" excede ${maxLength} caracteres.`,
    );
  }
  return trimmed;
}

/**
 * Valida uma data no formato 'YYYY-MM-DD'.
 * Rejeita datas invalidas como 2026-02-31.
 */
function parseDate(value, fieldName) {
  if (typeof value !== 'string' || !/^\d{4}-\d{2}-\d{2}$/.test(value)) {
    throw AppError.badRequest(
      `O campo "${fieldName}" deve estar no formato YYYY-MM-DD.`,
    );
  }
  const [year, month, day] = value.split('-').map(Number);
  const date = new Date(Date.UTC(year, month - 1, day));
  if (
    date.getUTCFullYear() !== year ||
    date.getUTCMonth() !== month - 1 ||
    date.getUTCDate() !== day
  ) {
    throw AppError.badRequest(`O campo "${fieldName}" contem uma data inexistente.`);
  }
  return value;
}

/**
 * Valida o periodo aceito pelas telas de Progresso/Evolucao.
 * 'semanal' -> ultimos 7 dias | 'mensal' -> ultimos 30 dias
 */
const PERIODOS = { semanal: 7, mensal: 30 };

function parsePeriodo(value, fallback = 'semanal') {
  const periodo = (value || fallback).toString().toLowerCase();
  if (!Object.prototype.hasOwnProperty.call(PERIODOS, periodo)) {
    throw AppError.badRequest(
      `O parametro "periodo" deve ser "semanal" ou "mensal".`,
    );
  }
  return { periodo, dias: PERIODOS[periodo] };
}

/** Arredonda para N casas decimais devolvendo Number (nao string). */
function round(value, decimals = 1) {
  if (value === null || value === undefined) return null;
  const factor = 10 ** decimals;
  return Math.round(Number(value) * factor) / factor;
}

module.exports = {
  parseId,
  parseCursor,
  parseNumber,
  parseText,
  parseDate,
  parsePeriodo,
  round,
};
