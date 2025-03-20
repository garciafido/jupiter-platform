/**
 * Configuración de colas
 */
export interface QueueConfig {
  url: string;
  mainQueue: string;
  retryQueue: string;
  deadLetterQueue: string;
  resultQueue: string;
  prefetch: number;
}

/**
 * Configuración de reintentos
 */
export interface RetryConfig {
  maxRetries: number;
  backoffMultiplier: number;
}

/**
 * Configuración de GraphQL
 */
export interface GraphQLConfig {
  url: string;
}

/**
 * Configuración del navegador
 */
export interface BrowserConfig {
  headless: boolean;
  timeout: number;
  args?: string[];
}

/**
 * Configuración completa del worker
 */
export interface WorkerConfig {
  queue: QueueConfig;
  retry: RetryConfig;
  graphql: GraphQLConfig;
  browser?: BrowserConfig;
  scraper?: ScraperConfig;
}

/**
 * Configuración específica para scrapers
 */
export interface ScraperConfig {
  maxConcurrentBrowsers: number;
  defaultMethod: ScraperMethod;
  userAgent?: string;
}

/**
 * Método de scraping a utilizar
 */
export enum ScraperMethod {
  AUTO = 'auto',        // Decide automáticamente
  BROWSER = 'browser',  // Usa navegador (Playwright)
  LIGHT = 'light'       // Usa método ligero (Got+Cheerio)
}

/**
 * Estados posibles de una tarea
 */
export enum TaskStatus {
  PENDING = 'PENDING',
  PROCESSING = 'PROCESSING',
  COMPLETED = 'COMPLETED',
  FAILED = 'FAILED',
  RETRY_SCHEDULED = 'RETRY_SCHEDULED',
}

/**
 * Interfaz base para todas las tareas
 */
export interface WorkerTask {
  id: string;
  retryCount?: number;
  [key: string]: any;
}

/**
 * Opciones para el scraping
 */
export interface ScraperOptions {
  method?: ScraperMethod;
  waitFor?: string;
  timeout?: number;
  removeHtml?: boolean;
  maxLength?: number;
  keywords?: string[];
  formData?: FormDataEntry[];
  clicks?: ClickAction[];
  screenshot?: boolean;
  proxy?: ProxySettings;
  proxyRotation?: ProxyRotationSettings;
  antiDetection?: AntiDetectionSettings;
  userAgent?: string;
  loadImages?: boolean; // Flag para controlar si se cargan imágenes
}
/**
 * Acción de completar un formulario
 */
export interface FormDataEntry {
  selector: string;
  value: string;
  type?: 'text' | 'select' | 'checkbox' | 'radio';
}

/**
 * Acción de clic
 */
export interface ClickAction {
  selector: string;
  waitAfter?: number; // ms a esperar después del clic
}

/**
 * Interfaz específica para tareas de scraping
 */
export interface ScraperTask extends WorkerTask {
  url?: string;
  selector?: string;
  data?: {
    url?: string;
    text?: string;
    options?: ScraperOptions;
    [key: string]: any;
  };
}

/**
 * Estadísticas del resultado
 */
export interface ScraperStats {
  originalLength?: number;
  processedLength?: number;
  wordCount?: number;
  executionTimeMs?: number;
  method?: ScraperMethod;
  [key: string]: any;
}

/**
 * Interfaz para resultados de scraping
 */
export interface ScraperResult {
  id: string;
  url?: string;
  data?: any;
  text: string;
  html?: string;
  processedText?: string;
  extractedData?: any;
  stats?: ScraperStats;
  timestamp: string;
  error?: string;
  screenshot?: string; // Base64
}

/**
 * Registro de log para una tarea
 */
export interface TaskLog {
  timestamp: Date;
  level: 'info' | 'warning' | 'error' | 'debug';
  message: string;
  data?: Record<string, any>;
}

/**
 * Contexto de ejecución para una tarea
 */
export interface TaskContext {
  id: string;
  attempt: number;
  startedAt: Date;
  logs: TaskLog[];
}

/**
 * Actualización de progreso para una tarea
 */
export interface ProgressUpdate {
  status: TaskStatus;
  progress?: number;
  currentStep?: string;
  result?: string | any;
  errorMessage?: string;
  retryCount?: number;
  nextRetry?: string;
  lastAttempt?: string;
  completedAt?: string;
  failedAt?: string;
  logs?: TaskLog[];
}

// Añade estas interfaces a tu archivo types.ts

/**
 * Configuración de proxy
 */
export interface ProxySettings {
  server: string;
  username?: string;
  password?: string;
}

/**
 * Configuración para rotación de proxies
 */
export interface ProxyRotationSettings {
  enabled: boolean;
  proxies: ProxySettings[];
  rotationInterval?: number; // Milisegundos entre rotaciones
  rotationStrategy?: 'round-robin' | 'random';
}

/**
 * Configuración de técnicas anti-detección
 */
export interface AntiDetectionSettings {
  enabled: boolean;
  randomizeUserAgent?: boolean;
  usePlugins?: boolean;
  evasionTechniques?: string[]; // Técnicas específicas a utilizar ('canvas-fingerprint', 'timezone-mask', etc.)
  customUserAgent?: string;
}

/**
 * Opciones del contexto del navegador
 */
export interface BrowserContextOptions {
  viewport?: { width: number; height: number };
  userAgent?: string;
  // Otras opciones que Playwright soporta
}
