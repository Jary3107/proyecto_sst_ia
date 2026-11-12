/**
 * SST-IA Frontend Application Controller (TechNova Edition)
 * Maneja navegación SPA, cámara en vivo, análisis IA, descarte de fotos borrosas,
 * eliminación de seguimientos, validación humana y descarga de PDF.
 */

// Estado global de la aplicación
const appState = {
  inspeccionActiva: null,
  inspecciones: [],
  fotoBase64Actual: null,
  analisisActual: null,
  evidenciaActualId: null,
  hallazgoActualId: null,
  streamCamara: null,
  categorias: {},
  catalogoNormas: {}
};

// Elementos del DOM
const dom = {
  tabs: document.querySelectorAll('.nav-tab-btn'),
  panes: document.querySelectorAll('.tab-pane'),
  activeInspectionCard: document.getElementById('active-inspection-banner'),
  kpiTotalInspecciones: document.getElementById('kpi-total-inspecciones'),
  kpiTotalHallazgos: document.getElementById('kpi-total-hallazgos'),
  kpiValidados: document.getElementById('kpi-validados'),
  kpiCumplimiento: document.getElementById('kpi-cumplimiento'),
  navCountEvidencias: document.getElementById('nav-count-evidencias'),
  
  // Inspección activa
  currentInspNum: document.getElementById('current-insp-num'),
  currentInspSede: document.getElementById('current-insp-sede'),
  currentInspArea: document.getElementById('current-insp-area'),
  currentInspResp: document.getElementById('current-insp-resp'),
  evidenceGrid: document.getElementById('evidence-grid'),
  emptyEvidenceState: document.getElementById('empty-evidence-state'),
  btnFinalizarInsp: document.getElementById('btn-finalizar-insp'),
  btnDescargarPdfActivo: document.getElementById('btn-descargar-pdf-activo'),
  
  // Captura y Control de Calidad
  fileInput: document.getElementById('file-input'),
  dropZone: document.getElementById('drop-zone'),
  previewImg: document.getElementById('preview-img'),
  placeholderTextBox: document.getElementById('placeholder-text-box'),
  cameraVideo: document.getElementById('camera-stream'),
  btnStartCamera: document.getElementById('btn-start-camera'),
  btnCameraText: document.getElementById('btn-camera-text'),
  btnSnapPhoto: document.getElementById('btn-snap-photo'),
  inputObs: document.getElementById('input-observacion'),
  inputUbicacion: document.getElementById('input-ubicacion'),
  selectTipo: document.getElementById('select-tipo-esperado'),
  btnAnalizarEvidencia: document.getElementById('btn-analizar-evidencia'),
  captureStatusBadge: document.getElementById('capture-status-badge'),
  
  // Barra de imagen cargada (Descarte / Cancelar)
  photoLoadedBar: document.getElementById('photo-loaded-bar'),
  btnDescartarFoto: document.getElementById('btn-descartar-foto'),
  btnCambiarFoto: document.getElementById('btn-cambiar-foto'),
  
  // Overlay de análisis
  overlayAnalizando: document.getElementById('overlay-analizando'),
  btnCancelarAnalisis: document.getElementById('btn-cancelar-analisis'),
  step1: document.getElementById('step-1'),
  step2: document.getElementById('step-2'),
  step3: document.getElementById('step-3'),
  step4: document.getElementById('step-4'),
  
  // Modal Resultado IA
  modalResultado: document.getElementById('modal-resultado-ia'),
  resImgAnotada: document.getElementById('res-img-anotada'),
  resElemento: document.getElementById('res-elemento'),
  resCategoriaBadge: document.getElementById('res-categoria-badge'),
  resCondicion: document.getElementById('res-condicion'),
  resConfianzaBar: document.getElementById('res-confianza-bar'),
  resConfianzaTxt: document.getElementById('res-confianza-txt'),
  resRecomendacion: document.getElementById('res-recomendacion'),
  btnEliminarEvidenciaModal: document.getElementById('btn-eliminar-evidencia-modal'),
  btnRechazarHallazgo: document.getElementById('btn-rechazar-hallazgo'),
  btnContinuarRevision: document.getElementById('btn-continuar-revision'),
  btnAprobarDirectoModal: document.getElementById('btn-aprobar-directo-modal'),
  
  // Modal Edición / Validación Humana
  modalRevision: document.getElementById('modal-revision'),
  editElemento: document.getElementById('edit-elemento'),
  editCategoria: document.getElementById('edit-categoria'),
  editCondicion: document.getElementById('edit-condicion'),
  editRecomendacion: document.getElementById('edit-recomendacion'),
  btnGuardarPendiente: document.getElementById('btn-guardar-pendiente'),
  btnAprobarValidado: document.getElementById('btn-aprobar-validado'),
  
  // Modal Nueva Inspección
  modalNuevaInsp: document.getElementById('modal-nueva-inspeccion'),
  formNuevaInsp: document.getElementById('form-nueva-inspeccion'),
  
  // Historial
  tablaHistorial: document.getElementById('tabla-historial-body'),
  
  // Datasets
  curlInput: document.getElementById('curl-input'),
  btnImportarCurl: document.getElementById('btn-importar-curl'),
  curlStatusMsg: document.getElementById('curl-status-msg'),
  btnEntrenarYolo: document.getElementById('btn-entrenar-yolo'),
  trainStatusMsg: document.getElementById('train-status-msg')
};

// ---------------------------------------------------------
// INICIALIZACIÓN
// ---------------------------------------------------------
document.addEventListener('DOMContentLoaded', async () => {
  setupNavigation();
  setupEventListeners();
  await cargarCategorias();
  setupCalculadoraNormas();
  setupFichaNormativa();
  await refrescarDatos();
});

// Navegación entre pestañas SPA
function setupNavigation() {
  dom.tabs.forEach(tab => {
    tab.addEventListener('click', () => {
      const targetId = tab.dataset.target;
      switchTab(targetId);
    });
  });
}

window.switchTab = function(targetId) {
  dom.tabs.forEach(t => t.classList.remove('active'));
  dom.panes.forEach(p => p.classList.remove('active'));

  const activeTab = document.querySelector(`[data-target="${targetId}"]`);
  const activePane = document.getElementById(targetId);

  if (activeTab) activeTab.classList.add('active');
  if (activePane) activePane.classList.add('active');

  // Detener cámara si salimos de la pestaña de captura
  if (targetId !== 'tab-captura' && appState.streamCamara) {
    detenerCamara();
  }
};

// ---------------------------------------------------------
// CARGA DE DATOS DESDE LA API
// ---------------------------------------------------------
async function cargarCategorias() {
  try {
    const res = await fetch('/api/catalogo_normas');
    if (res.ok) {
      const data = await res.json();
      appState.categorias = data.categorias || {};
      appState.catalogoNormas = data.catalogo || {};
    } else {
      const resCat = await fetch('/api/categorias');
      if (resCat.ok) {
        const d = await resCat.json();
        appState.categorias = d.categorias || {};
      }
    }
  } catch (e) {
    console.warn("No se pudieron cargar normas y categorías:", e);
  }
}

async function refrescarDatos() {
  try {
    const res = await fetch('/api/inspecciones');
    if (res.ok) {
      appState.inspecciones = await res.json();
      actualizarDashboard();
      actualizarHistorial();
      
      // Mantener la inspección activa actual o buscar la primera activa
      let activa = null;
      if (appState.inspeccionActiva && appState.inspeccionActiva.id) {
        activa = appState.inspecciones.find(i => i.id === appState.inspeccionActiva.id);
      }
      if (!activa) {
        activa = appState.inspecciones.find(i => i.estado === 'enCurso') || appState.inspecciones[0] || null;
      }
      appState.inspeccionActiva = activa;
      actualizarVistaInspeccionActiva();
    }
  } catch (e) {
    console.error("Error al refrescar datos:", e);
  }
}

function actualizarDashboard() {
  const totalInsp = appState.inspecciones.length;
  let totalH = 0;
  let validados = 0;
  let conformes = 0;

  appState.inspecciones.forEach(i => {
    (i.evidencias || []).forEach(ev => {
      (ev.hallazgos || []).forEach(h => {
        totalH++;
        if (h.estado === 'validado') validados++;
        if ((h.condicion || '').toLowerCase().includes('conforme')) conformes++;
      });
    });
  });

  const cumplimiento = totalH > 0 ? Math.round((conformes / totalH) * 100) : 100;

  if (dom.kpiTotalInspecciones) dom.kpiTotalInspecciones.textContent = totalInsp;
  if (dom.kpiTotalHallazgos) dom.kpiTotalHallazgos.textContent = totalH;
  if (dom.kpiValidados) dom.kpiValidados.textContent = validados;
  if (dom.kpiCumplimiento) dom.kpiCumplimiento.textContent = `${cumplimiento}%`;

  // Banner en dashboard
  if (appState.inspeccionActiva) {
    dom.activeInspectionCard.style.display = 'block';
    const numEl = document.getElementById('dash-active-num');
    const areaEl = document.getElementById('dash-active-area');
    if (numEl) numEl.textContent = appState.inspeccionActiva.numero;
    if (areaEl) areaEl.textContent = `${appState.inspeccionActiva.sede} — ${appState.inspeccionActiva.area}`;
  } else {
    dom.activeInspectionCard.style.display = 'none';
  }
}

function actualizarVistaInspeccionActiva() {
  const countEv = (appState.inspeccionActiva?.evidencias || []).length;
  if (dom.navCountEvidencias) dom.navCountEvidencias.textContent = countEv;

  if (!appState.inspeccionActiva) {
    dom.currentInspNum.textContent = 'Ninguna activa';
    dom.currentInspSede.textContent = '---';
    dom.currentInspArea.textContent = '---';
    dom.currentInspResp.textContent = '---';
    dom.btnFinalizarInsp.disabled = true;
    dom.btnDescargarPdfActivo.disabled = true;
    dom.evidenceGrid.innerHTML = '';
    dom.emptyEvidenceState.style.display = 'block';
    return;
  }

  const insp = appState.inspeccionActiva;
  dom.currentInspNum.textContent = insp.numero;
  dom.currentInspSede.textContent = `${insp.sede} (${insp.edificio})`;
  dom.currentInspArea.textContent = insp.area;
  dom.currentInspResp.textContent = insp.responsable;
  dom.btnFinalizarInsp.disabled = false;
  dom.btnDescargarPdfActivo.disabled = false;

  const evidencias = insp.evidencias || [];
  if (evidencias.length === 0) {
    dom.emptyEvidenceState.style.display = 'block';
    dom.evidenceGrid.innerHTML = '';
  } else {
    dom.emptyEvidenceState.style.display = 'none';
    renderEvidenciasGrid(evidencias);
  }
}

function renderEvidenciasGrid(evidencias) {
  dom.evidenceGrid.innerHTML = '';
  evidencias.forEach((ev, idx) => {
    const card = document.createElement('div');
    card.className = 'evidence-card';
    
    const h = (ev.hallazgos && ev.hallazgos.length > 0) ? ev.hallazgos[0] : null;
    const elemento = h ? h.elemento : 'Sin diagnóstico';
    const categoria = h ? h.categoria : 'Amarillas';
    const estado = h ? h.estado : 'pendiente';
    const condicion = h ? h.condicion : 'N/A';
    
    let badgeClass = 'badge-amarillo';
    if (categoria === 'Rojas') badgeClass = 'badge-rojo';
    if (categoria === 'Azules') badgeClass = 'badge-azul';
    if (categoria === 'Verdes') badgeClass = 'badge-verde';

    const estadoBadge = estado === 'validado' ? 'badge-verde' : estado === 'rechazado' ? 'badge-rojo' : 'badge-amarillo';

    card.innerHTML = `
      <div class="evidence-img-container">
        <img src="${ev.foto_url || ev.foto_path}" alt="Evidencia SST #${idx+1}">
        <span class="badge ${estadoBadge} evidence-badge-top-left">${estado}</span>
        <span class="badge ${badgeClass} evidence-badge-top-right">${categoria}</span>
      </div>
      <div class="evidence-body">
        <div>
          <div class="evidence-title-row">
            <h4 class="evidence-title">${elemento}</h4>
          </div>
          <div class="evidence-meta-row">
            📍 <b>Ubicación:</b> ${ev.ubicacion || 'General'}
          </div>
          <div class="evidence-meta-row">
            📝 <b>Condición:</b> ${condicion}
          </div>
        </div>
        <div class="evidence-actions-row">
          <button class="btn btn-secondary btn-sm" style="flex: 1;" onclick="abrirEdicionHallazgo('${h ? h.id : ''}')">
            ✏️ Validar / Editar
          </button>
          <button class="btn btn-danger-soft btn-sm" onclick="eliminarSeguimiento('${ev.id}')" title="Eliminar este seguimiento fotográfico">
            🗑️ Eliminar
          </button>
        </div>
      </div>
    `;
    dom.evidenceGrid.appendChild(card);
  });
}

// ---------------------------------------------------------
// ELIMINACIÓN DE SEGUIMIENTOS E INSPECCIONES
// ---------------------------------------------------------
window.eliminarSeguimiento = async function(evidenciaId) {
  if (!appState.inspeccionActiva || !evidenciaId) return;
  if (!confirm("¿Deseas eliminar este seguimiento/evidencia de la inspección? Esta acción no se puede deshacer.")) {
    return;
  }

  try {
    let res = await fetch(`/api/inspecciones/${appState.inspeccionActiva.id}/evidencias/${evidenciaId}`, {
      method: 'DELETE'
    });
    if (!res.ok) {
      // Fallback con POST
      res = await fetch(`/api/inspecciones/${appState.inspeccionActiva.id}/evidencias/${evidenciaId}/eliminar`, {
        method: 'POST'
      });
    }
    if (!res.ok) throw new Error("No se pudo eliminar el seguimiento");
    
    await refrescarDatos();
  } catch (err) {
    alert("Error al eliminar el seguimiento: " + err.message);
  }
};

window.eliminarInspeccion = async function(inspeccionId) {
  if (!confirm("¿Estás seguro de eliminar esta inspección completa y todos sus registros fotográficos?")) {
    return;
  }

  try {
    let res = await fetch(`/api/inspecciones/${inspeccionId}`, {
      method: 'DELETE'
    });
    if (!res.ok) {
      // Fallback con POST
      res = await fetch(`/api/inspecciones/${inspeccionId}/eliminar`, {
        method: 'POST'
      });
    }
    if (!res.ok) throw new Error("No se pudo eliminar la inspección");

    await refrescarDatos();
  } catch (err) {
    alert("Error al eliminar inspección: " + err.message);
  }
};

function actualizarHistorial() {
  dom.tablaHistorial.innerHTML = '';
  if (appState.inspecciones.length === 0) {
    dom.tablaHistorial.innerHTML = `<tr><td colspan="7" style="text-align: center; color: var(--text-dim); padding: 2.5rem;">No hay inspecciones registradas aún.</td></tr>`;
    return;
  }

  appState.inspecciones.forEach(i => {
    const tr = document.createElement('tr');
    const isActiva = i.estado === 'enCurso';
    tr.innerHTML = `
      <td><b>${i.numero}</b></td>
      <td>${i.fecha}</td>
      <td>${i.sede} — ${i.edificio}</td>
      <td>${i.area}</td>
      <td>${i.responsable}</td>
      <td>
        <span class="badge ${isActiva ? 'badge-amarillo' : 'badge-verde'}">
          ${isActiva ? 'EN CURSO' : 'FINALIZADA'}
        </span>
      </td>
      <td style="text-align: right;">
        <div style="display: inline-flex; gap: 0.4rem;">
          <a href="/api/inspecciones/${i.id}/informe.pdf" target="_blank" class="btn btn-secondary btn-sm" title="Descargar informe técnico PDF">
            📄 PDF
          </a>
          <button class="btn btn-danger-soft btn-sm" onclick="eliminarInspeccion('${i.id}')" title="Eliminar registro de auditoría">
            🗑️
          </button>
        </div>
      </td>
    `;
    dom.tablaHistorial.appendChild(tr);
  });
}

// ---------------------------------------------------------
// EVENT LISTENERS & CONTROL DE FOTOS
// ---------------------------------------------------------
function setupEventListeners() {
  // Drag and drop & Selección de archivos
  dom.dropZone.addEventListener('click', (e) => {
    // Si se hizo click en el video o preview, no volver a disparar si estamos interactuando
    if (e.target !== dom.previewImg && e.target !== dom.cameraVideo) {
      dom.fileInput.click();
    }
  });
  dom.fileInput.addEventListener('change', handleFileSelect);

  dom.dropZone.addEventListener('dragover', (e) => {
    e.preventDefault();
    dom.dropZone.classList.add('dragover');
  });
  dom.dropZone.addEventListener('dragleave', () => dom.dropZone.classList.remove('dragover'));
  dom.dropZone.addEventListener('drop', (e) => {
    e.preventDefault();
    dom.dropZone.classList.remove('dragover');
    if (e.dataTransfer.files && e.dataTransfer.files[0]) {
      procesarArchivoImagen(e.dataTransfer.files[0]);
    }
  });

  // Cámara
  dom.btnStartCamera.addEventListener('click', toggleCamera);
  dom.btnSnapPhoto.addEventListener('click', snapCameraPhoto);

  // Botones de descarte y cambio de foto si salió borrosa
  if (dom.btnDescartarFoto) {
    dom.btnDescartarFoto.addEventListener('click', descartarFotoActual);
  }
  if (dom.btnCambiarFoto) {
    dom.btnCambiarFoto.addEventListener('click', () => dom.fileInput.click());
  }

  // Cancelar análisis en overlay
  if (dom.btnCancelarAnalisis) {
    dom.btnCancelarAnalisis.addEventListener('click', () => {
      ocultarAnimacionAnalizando();
    });
  }

  // Analizar evidencia
  dom.btnAnalizarEvidencia.addEventListener('click', ejecutarAnalisisEvidencia);

  // Botones de resultado IA
  dom.btnEliminarEvidenciaModal.addEventListener('click', handleEliminarEvidenciaDesdeModal);
  dom.btnRechazarHallazgo.addEventListener('click', rechazarHallazgo);
  dom.btnContinuarRevision.addEventListener('click', () => {
    dom.modalResultado.style.display = 'none';
    abrirModalRevision();
  });
  if (dom.btnAprobarDirectoModal) {
    dom.btnAprobarDirectoModal.addEventListener('click', () => guardarRevision('validado'));
  }

  // Botones de validación humana
  dom.btnGuardarPendiente.addEventListener('click', () => guardarRevision('pendiente'));
  dom.btnAprobarValidado.addEventListener('click', () => guardarRevision('validado'));

  // Modales
  document.getElementById('btn-nueva-inspeccion-header').addEventListener('click', abrirModalNuevaInsp);
  document.getElementById('btn-dash-nueva-insp').addEventListener('click', abrirModalNuevaInsp);
  document.getElementById('btn-dash-ver-activa').addEventListener('click', () => switchTab('tab-inspeccion'));
  document.getElementById('btn-capturar-desde-insp').addEventListener('click', () => switchTab('tab-captura'));

  dom.formNuevaInsp.addEventListener('submit', handleCrearNuevaInspeccion);
  dom.btnFinalizarInsp.addEventListener('click', handleFinalizarInspeccion);
  dom.btnDescargarPdfActivo.addEventListener('click', () => {
    if (appState.inspeccionActiva) {
      window.open(`/api/inspecciones/${appState.inspeccionActiva.id}/informe.pdf`, '_blank');
    }
  });

  // Dataset cURL y entrenamiento
  dom.btnImportarCurl.addEventListener('click', handleImportarCurl);
  dom.btnEntrenarYolo.addEventListener('click', handleEntrenarYolo);
}

function handleFileSelect(e) {
  if (e.target.files && e.target.files[0]) {
    procesarArchivoImagen(e.target.files[0]);
  }
}

function procesarArchivoImagen(file) {
  const reader = new FileReader();
  reader.onload = (event) => {
    appState.fotoBase64Actual = event.target.result;
    dom.previewImg.src = appState.fotoBase64Actual;
    dom.previewImg.style.display = 'block';
    if (dom.placeholderTextBox) dom.placeholderTextBox.style.display = 'none';
    dom.btnAnalizarEvidencia.disabled = false;
    
    // Mostrar barra de descarte / cambio de foto
    if (dom.photoLoadedBar) dom.photoLoadedBar.style.display = 'flex';
    if (dom.captureStatusBadge) {
      dom.captureStatusBadge.textContent = 'Foto lista';
      dom.captureStatusBadge.className = 'badge badge-verde';
    }
  };
  reader.readAsDataURL(file);
}

// Descartar imagen seleccionada (porque salió corrida, borrosa o equivocada)
function descartarFotoActual() {
  appState.fotoBase64Actual = null;
  dom.previewImg.src = '';
  dom.previewImg.style.display = 'none';
  if (dom.placeholderTextBox) dom.placeholderTextBox.style.display = 'block';
  dom.fileInput.value = '';
  dom.btnAnalizarEvidencia.disabled = true;

  if (dom.photoLoadedBar) dom.photoLoadedBar.style.display = 'none';
  if (dom.captureStatusBadge) {
    dom.captureStatusBadge.textContent = 'Esperando foto';
    dom.captureStatusBadge.className = 'badge badge-tech';
  }
}

async function toggleCamera() {
  if (appState.streamCamara) {
    detenerCamara();
  } else {
    try {
      const stream = await navigator.mediaDevices.getUserMedia({
        video: { facingMode: "environment", width: { ideal: 1280 } },
        audio: false
      });
      appState.streamCamara = stream;
      dom.cameraVideo.srcObject = stream;
      dom.cameraVideo.style.display = 'block';
      dom.cameraVideo.play();
      dom.btnSnapPhoto.style.display = 'inline-flex';
      dom.btnCameraText.textContent = 'Detener Cámara';
      if (dom.placeholderTextBox) dom.placeholderTextBox.style.display = 'none';
      if (dom.previewImg) dom.previewImg.style.display = 'none';
    } catch (err) {
      alert("No se pudo acceder a la cámara: " + err.message);
    }
  }
}

function detenerCamara() {
  if (appState.streamCamara) {
    appState.streamCamara.getTracks().forEach(track => track.stop());
    appState.streamCamara = null;
    dom.cameraVideo.style.display = 'none';
    dom.btnSnapPhoto.style.display = 'none';
    dom.btnCameraText.textContent = 'Abrir Cámara';
    if (!appState.fotoBase64Actual && dom.placeholderTextBox) {
      dom.placeholderTextBox.style.display = 'block';
    }
  }
}

function snapCameraPhoto() {
  const canvas = document.createElement('canvas');
  canvas.width = dom.cameraVideo.videoWidth || 640;
  canvas.height = dom.cameraVideo.videoHeight || 480;
  const ctx = canvas.getContext('2d');
  ctx.drawImage(dom.cameraVideo, 0, 0, canvas.width, canvas.height);
  
  appState.fotoBase64Actual = canvas.toDataURL('image/jpeg', 0.9);
  dom.previewImg.src = appState.fotoBase64Actual;
  dom.previewImg.style.display = 'block';
  dom.btnAnalizarEvidencia.disabled = false;
  
  if (dom.photoLoadedBar) dom.photoLoadedBar.style.display = 'flex';
  if (dom.captureStatusBadge) {
    dom.captureStatusBadge.textContent = 'Foto lista';
    dom.captureStatusBadge.className = 'badge badge-verde';
  }

  detenerCamara();
}

// ---------------------------------------------------------
// FLUJO DE ANÁLISIS IA (4 ETAPAS ANIMADAS)
// ---------------------------------------------------------
async function ejecutarAnalisisEvidencia() {
  if (!appState.inspeccionActiva) {
    alert("Primero debes crear o tener una inspección activa.");
    switchTab('tab-inspeccion');
    return;
  }
  if (!appState.fotoBase64Actual) {
    alert("Por favor toma o selecciona una fotografía primero.");
    return;
  }

  // Mostrar pantalla animada de 4 etapas
  mostrarAnimacionAnalizando();

  try {
    const payload = {
      foto_base64: appState.fotoBase64Actual,
      observacion: dom.inputObs.value.trim(),
      ubicacion: dom.inputUbicacion.value.trim(),
      tipo_esperado: dom.selectTipo.value
    };

    const res = await fetch(`/api/inspecciones/${appState.inspeccionActiva.id}/evidencias`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(payload)
    });

    if (!res.ok) throw new Error("Error en el servidor al analizar evidencia");

    const data = await res.json();
    appState.analisisActual = data.analisis_completo;
    appState.evidenciaActualId = data.evidencia.id;
    appState.hallazgoActualId = data.hallazgo.id;

    // Refrescar inmediatamente los datos para que la evidencia quede vinculada a la vista
    await refrescarDatos();

    // Completar checkpoints visuales
    marcarPaso(4);
    setTimeout(() => {
      ocultarAnimacionAnalizando();
      mostrarResultadoIA(data.analisis_completo);
    }, 500);

  } catch (err) {
    ocultarAnimacionAnalizando();
    alert("Error al analizar la evidencia: " + err.message);
  }
}

function mostrarAnimacionAnalizando() {
  dom.overlayAnalizando.style.display = 'flex';
  [dom.step1, dom.step2, dom.step3, dom.step4].forEach(s => {
    if (s) s.className = 'step-item';
  });

  if (dom.step1) dom.step1.className = 'step-item active';
  setTimeout(() => {
    if (dom.step1) dom.step1.className = 'step-item done';
    if (dom.step2) dom.step2.className = 'step-item active';
  }, 350);
  setTimeout(() => {
    if (dom.step2) dom.step2.className = 'step-item done';
    if (dom.step3) dom.step3.className = 'step-item active';
  }, 750);
  setTimeout(() => {
    if (dom.step3) dom.step3.className = 'step-item done';
    if (dom.step4) dom.step4.className = 'step-item active';
  }, 1150);
}

function marcarPaso(num) {
  for (let i = 1; i <= num; i++) {
    const step = dom[`step${i}`];
    if (step) step.className = 'step-item done';
  }
}

function ocultarAnimacionAnalizando() {
  dom.overlayAnalizando.style.display = 'none';
}

// ---------------------------------------------------------
// PANTALLAS DE RESULTADO Y REVISIÓN ÉTICA
// ---------------------------------------------------------
function mostrarResultadoIA(analisis) {
  dom.resElemento.textContent = analisis.elemento;
  dom.resCondicion.textContent = analisis.condicion;
  dom.resRecomendacion.textContent = analisis.recomendacion;

  const cat = analisis.categoria || 'Amarillas';
  dom.resCategoriaBadge.textContent = cat;
  dom.resCategoriaBadge.className = `badge badge-${cat === 'Rojas' ? 'rojo' : cat === 'Azules' ? 'azul' : cat === 'Verdes' ? 'verde' : 'amarillo'}`;

  const confPercent = Math.round(analisis.confianza * 100);
  dom.resConfianzaTxt.textContent = `${confPercent}%`;
  dom.resConfianzaBar.style.width = `${confPercent}%`;
  dom.resConfianzaBar.style.backgroundColor = confPercent > 80 ? 'var(--sst-verde)' : confPercent > 50 ? 'var(--sst-amarillo)' : 'var(--sst-rojo)';

  // Imagen con bounding box si vino anotada
  if (analisis.foto_anotada_base64) {
    dom.resImgAnotada.src = `data:image/jpeg;base64,${analisis.foto_anotada_base64}`;
  } else {
    dom.resImgAnotada.src = appState.fotoBase64Actual;
  }

  // Buscar en catálogo de normas para enriquecer si falta algún campo
  let itemNormativo = null;
  const elemLower = (analisis.elemento || '').toLowerCase();
  for (const k in appState.catalogoNormas) {
    const item = appState.catalogoNormas[k];
    if (elemLower.includes(k) || (item.elemento && elemLower.includes(item.elemento.toLowerCase()))) {
      itemNormativo = item;
      break;
    }
  }

  const normaTxt = analisis.norma || (itemNormativo ? itemNormativo.norma : "NTC 1461 / NSR-10 / Res. 2400 de 1979");
  const colSeg = analisis.color_seguridad || (itemNormativo ? itemNormativo.color_seguridad : "Color de Seguridad Normativo");
  const colCont = analisis.color_contraste || (itemNormativo ? itemNormativo.color_contraste : "Blanco/Negro");
  const cobMin = analisis.cobertura_min_color || (itemNormativo ? itemNormativo.cobertura_min_color : ">= 50% de la superficie");
  const formaGeom = analisis.forma_geometrica || (itemNormativo ? itemNormativo.forma_geometrica : "Geometría normalizada NTC 1461");
  const tamRec = analisis.tamano_recomendado || (itemNormativo ? itemNormativo.tamano_recomendado : "20x20 cm (d <= 10m) | 30x30 cm (d <= 15m)");
  const fotolum = analisis.fotoluminiscencia || (itemNormativo ? itemNormativo.fotoluminiscencia : "Poliestireno Clase A (210 mcd/m²)");
  const altMont = analisis.altura_montaje || (itemNormativo ? itemNormativo.altura_montaje : "1.60m a 1.80m al centro de la señal");
  const demarc = analisis.demarcacion_piso || (itemNormativo ? itemNormativo.demarcacion_piso : "Franja amarilla de 10 cm (Res. 2400/79)");

  const elNorma = document.getElementById('res-norma');
  if (elNorma) elNorma.textContent = normaTxt;

  const elColoresVal = document.getElementById('res-colores-val');
  if (elColoresVal) elColoresVal.textContent = `${colSeg} / Contraste ${colCont}`;

  const elCobVal = document.getElementById('res-cobertura-val');
  if (elCobVal) elCobVal.textContent = cobMin;

  const elFormaVal = document.getElementById('res-forma-val');
  if (elFormaVal) elFormaVal.textContent = formaGeom;

  const elTamanoVal = document.getElementById('res-tamano-val');
  if (elTamanoVal) elTamanoVal.textContent = tamRec;

  const elFotolumVal = document.getElementById('res-fotolum-val');
  if (elFotolumVal) elFotolumVal.textContent = fotolum;

  const elAlturaVal = document.getElementById('res-altura-val');
  if (elAlturaVal) elAlturaVal.textContent = altMont;

  const elDemarcVal = document.getElementById('res-demarcacion-val');
  if (elDemarcVal) elDemarcVal.textContent = demarc;

  // Llenar checklist interactivo para el SST
  const elChecklist = document.getElementById('res-checklist-list');
  if (elChecklist) {
    elChecklist.innerHTML = '';
    const checklistItems = (analisis.checklist_sst && analisis.checklist_sst.length) 
      ? analisis.checklist_sst 
      : (itemNormativo && itemNormativo.checklist_sst ? itemNormativo.checklist_sst : [
          "1. Verificar visibilidad directa y libre de obstáculos a más de 10 metros.",
          "2. Contrastes de color legibles sin decoloración por exposición a rayos UV.",
          "3. Fijación mecánica segura que impida desprendimientos ante sismos.",
          "4. Cumplimiento de especificaciones según la norma técnica del sector."
        ]);

    checklistItems.forEach((it, idx) => {
      const row = document.createElement('div');
      row.className = 'checklist-item-row';
      row.innerHTML = `
        <input type="checkbox" id="chk_modal_${idx}" class="checklist-check" checked>
        <label for="chk_modal_${idx}"><b>${it.slice(0, 3)}</b> ${it.slice(3)}</label>
      `;
      elChecklist.appendChild(row);
    });
  }

  dom.modalResultado.style.display = 'flex';
}

// Descartar y eliminar completamente la evidencia desde el modal si la foto salió corrida o borrosa
async function handleEliminarEvidenciaDesdeModal() {
  if (!appState.inspeccionActiva || !appState.evidenciaActualId) return;
  if (!confirm("¿Deseas descartar y eliminar completamente esta evidencia porque la foto salió borrosa o corrida?")) {
    return;
  }

  try {
    let res = await fetch(`/api/inspecciones/${appState.inspeccionActiva.id}/evidencias/${appState.evidenciaActualId}`, {
      method: 'DELETE'
    });
    if (!res.ok) {
      res = await fetch(`/api/inspecciones/${appState.inspeccionActiva.id}/evidencias/${appState.evidenciaActualId}/eliminar`, {
        method: 'POST'
      });
    }
    if (!res.ok) throw new Error("No se pudo eliminar la evidencia");

    dom.modalResultado.style.display = 'none';
    descartarFotoActual();
    await refrescarDatos();
  } catch (err) {
    alert("Error al eliminar la evidencia: " + err.message);
  }
}

function rechazarHallazgo() {
  if (confirm("¿Deseas marcar este hallazgo preliminar como rechazado en el informe?")) {
    guardarRevision('rechazado');
    dom.modalResultado.style.display = 'none';
  }
}

function abrirModalRevision() {
  const an = appState.analisisActual || {};
  dom.editElemento.value = an.elemento || '';
  dom.editCategoria.value = an.categoria || 'Amarillas';
  dom.editCondicion.value = an.condicion || 'Requiere verificación';
  dom.editRecomendacion.value = an.recomendacion || '';
  dom.modalRevision.style.display = 'flex';
}

window.abrirEdicionHallazgo = function(hallazgoId) {
  if (!hallazgoId) return;
  appState.hallazgoActualId = hallazgoId;
  
  // Buscar hallazgo en memoria
  let targetH = null;
  if (appState.inspeccionActiva) {
    for (const ev of appState.inspeccionActiva.evidencias || []) {
      const match = (ev.hallazgos || []).find(h => h.id === hallazgoId);
      if (match) { targetH = match; break; }
    }
  }

  if (targetH) {
    dom.editElemento.value = targetH.elemento;
    dom.editCategoria.value = targetH.categoria;
    dom.editCondicion.value = targetH.condicion;
    dom.editRecomendacion.value = targetH.recomendacion || '';
    dom.modalRevision.style.display = 'flex';
  }
};

async function guardarRevision(estado) {
  if (!appState.hallazgoActualId) return;

  const payload = {
    elemento: dom.editElemento.value.trim() || 'Elemento SST',
    categoria: dom.editCategoria.value,
    condicion: dom.editCondicion.value,
    recomendacion: dom.editRecomendacion.value.trim(),
    estado: estado
  };

  try {
    const res = await fetch(`/api/hallazgos/${appState.hallazgoActualId}`, {
      method: 'PUT',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(payload)
    });

    if (!res.ok) throw new Error("No se pudo actualizar el hallazgo");

    dom.modalRevision.style.display = 'none';
    dom.modalResultado.style.display = 'none';

    descartarFotoActual();
    dom.inputObs.value = '';
    dom.inputUbicacion.value = '';

    await refrescarDatos();
    switchTab('tab-inspeccion');

  } catch (err) {
    alert("Error al guardar hallazgo: " + err.message);
  }
}

// ---------------------------------------------------------
// NUEVA INSPECCIÓN Y FINALIZACIÓN
// ---------------------------------------------------------
function abrirModalNuevaInsp() {
  dom.modalNuevaInsp.style.display = 'flex';
}

window.cerrarModal = function(modalId) {
  const m = document.getElementById(modalId);
  if (m) m.style.display = 'none';
};

async function handleCrearNuevaInspeccion(e) {
  e.preventDefault();
  const payload = {
    sede: document.getElementById('input-nueva-sede').value.trim(),
    edificio: document.getElementById('input-nueva-edificio').value.trim(),
    area: document.getElementById('input-nueva-area').value.trim(),
    responsable: document.getElementById('input-nueva-responsable').value.trim()
  };

  try {
    const res = await fetch('/api/inspecciones', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(payload)
    });

    if (!res.ok) throw new Error("No se pudo crear la inspección");

    const nuevaInsp = await res.json();
    appState.inspeccionActiva = nuevaInsp;

    dom.modalNuevaInsp.style.display = 'none';
    dom.formNuevaInsp.reset();
    await refrescarDatos();
    switchTab('tab-inspeccion');
  } catch (err) {
    alert("Error al iniciar inspección: " + err.message);
  }
}

async function handleFinalizarInspeccion() {
  if (!appState.inspeccionActiva) return;
  if (!confirm(`¿Deseas finalizar oficialmente la inspección ${appState.inspeccionActiva.numero}? Se generará el reporte final en PDF.`)) {
    return;
  }

  try {
    const res = await fetch(`/api/inspecciones/${appState.inspeccionActiva.id}/finalizar`, {
      method: 'POST'
    });
    if (!res.ok) throw new Error("No se pudo finalizar la inspección");

    await refrescarDatos();
    switchTab('tab-historial');
  } catch (err) {
    alert("Error: " + err.message);
  }
}

// ---------------------------------------------------------
// DATASETS Y cURL
// ---------------------------------------------------------
async function handleImportarCurl() {
  const curlCmd = dom.curlInput.value.trim();
  if (!curlCmd) {
    alert("Por favor pega el comando cURL primero.");
    return;
  }

  dom.btnImportarCurl.disabled = true;
  dom.curlStatusMsg.style.display = 'block';
  dom.curlStatusMsg.innerHTML = '⏳ Descargando y descomprimiendo dataset desde Roboflow...';

  try {
    const res = await fetch('/api/datasets/importar_curl', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ curl_command: curlCmd })
    });

    const data = await res.json();
    if (!res.ok) throw new Error(data.detail || "Error al procesar el cURL");

    dom.curlStatusMsg.innerHTML = `
      <div style="color: var(--sst-verde); font-weight: 600;">
        ✅ ¡Dataset importado exitosamente!
      </div>
      <div style="font-size: 0.82rem; margin-top: 0.4rem; color: var(--text-muted);">
        Archivos encontrados: ${data.archivos_totales}<br/>
        Archivo de configuración: <code>${data.data_yaml || 'Pendiente'}</code>
      </div>
    `;

    if (data.data_yaml) {
      dom.btnEntrenarYolo.disabled = false;
      dom.btnEntrenarYolo.dataset.yaml = data.data_yaml;
    }

  } catch (err) {
    dom.curlStatusMsg.innerHTML = `<span style="color: var(--sst-rojo);">❌ ${err.message}</span>`;
  } finally {
    dom.btnImportarCurl.disabled = false;
  }
}

async function handleEntrenarYolo() {
  const yamlPath = dom.btnEntrenarYolo.dataset.yaml;
  if (!yamlPath) {
    alert("Primero importa un dataset con data.yaml");
    return;
  }

  dom.btnEntrenarYolo.disabled = true;
  dom.trainStatusMsg.style.display = 'block';
  dom.trainStatusMsg.innerHTML = '🚀 Iniciando entrenamiento con YOLOv8 en segundo plano...';

  try {
    const res = await fetch('/api/datasets/entrenar', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ data_yaml_path: yamlPath, epochs: 25 })
    });

    const data = await res.json();
    if (!res.ok) throw new Error(data.error || "Error al lanzar entrenamiento");

    dom.trainStatusMsg.innerHTML = `
      <div style="color: var(--sst-blue-light);">
        ⏳ Entrenamiento en progreso... Se actualizará automáticamente el modelo al finalizar.
      </div>
    `;

    // Polling de estado cada 5 segundos
    const interval = setInterval(async () => {
      const stRes = await fetch('/api/datasets/estado');
      if (stRes.ok) {
        const estado = await stRes.json();
        dom.trainStatusMsg.innerHTML = `<b>Estado:</b> ${estado.mensaje}`;
        if (!estado.en_progreso) {
          clearInterval(interval);
          dom.btnEntrenarYolo.disabled = false;
        }
      }
    }, 5000);

  } catch (err) {
    dom.trainStatusMsg.innerHTML = `<span style="color: var(--sst-rojo);">❌ ${err.message}</span>`;
    dom.btnEntrenarYolo.disabled = false;
  }
}

// ---------------------------------------------------------
// CALCULADORA METROLÓGICA DE SEÑALES SST (FÓRMULA S >= d² / 2000)
// ---------------------------------------------------------
function setupCalculadoraNormas() {
  const slider = document.getElementById('calc-distancia-slider');
  const display = document.getElementById('calc-dist-display');
  const selectCat = document.getElementById('calc-categoria-select');
  const selectEntorno = document.getElementById('calc-entorno-select');
  
  if (!slider) return;

  function recalcular() {
    const d = parseFloat(slider.value) || 10;
    if (display) display.textContent = d;

    // Fórmula NTC-ISO 3864 / UNE 23-034: S >= d² / 2000
    const S = (d * d) / 2000;
    const S_cm = S * 10000;
    const D_circular = Math.round((d / 40) * 100);

    const elArea = document.getElementById('calc-res-area');
    const elAreaCm = document.getElementById('calc-res-area-cm');
    const elFormato = document.getElementById('calc-res-formato');
    const elFormatoAlt = document.getElementById('calc-res-formato-alt');
    const elAltura = document.getElementById('calc-res-altura');
    const elGuidance = document.getElementById('calc-res-guidance');

    if (elArea) elArea.textContent = `${S.toFixed(4)} m²`;
    if (elAreaCm) elAreaCm.textContent = `(${Math.round(S_cm)} cm²)`;

    // Determinar formato comercial normalizado más cercano
    let formatoComercial = "20 x 20 cm";
    let formatoAlt = "o 30 x 15 cm";
    let alturaSugerida = "1.70 - 1.80 m (pared)";
    
    if (d <= 5) {
      formatoComercial = "10 x 10 cm";
      formatoAlt = "o 12 x 7 cm / 15 x 10 cm";
      alturaSugerida = "1.60 m (pared)";
    } else if (d <= 10) {
      formatoComercial = "20 x 20 cm";
      formatoAlt = "o 30 x 15 cm / 30 x 20 cm";
      alturaSugerida = "1.70 m - 1.80 m";
    } else if (d <= 15) {
      formatoComercial = "30 x 30 cm";
      formatoAlt = "o 40 x 20 cm";
      alturaSugerida = "1.80 m (pared) | >= 2.00m (bandera)";
    } else if (d <= 20) {
      formatoComercial = "42 x 42 cm (DIN A3)";
      formatoAlt = "o 60 x 20 cm";
      alturaSugerida = ">= 2.10 m (bandera o suspendida)";
    } else {
      formatoComercial = "60 x 60 cm (DIN A2)";
      formatoAlt = "o 80 x 40 cm / 80 x 80 cm";
      alturaSugerida = ">= 2.30 m (poste o pedestal)";
    }

    if (elFormato) elFormato.textContent = formatoComercial;
    if (elFormatoAlt) elFormatoAlt.textContent = formatoAlt;
    if (elAltura) elAltura.textContent = alturaSugerida;

    const catSel = selectCat ? selectCat.value : 'Verdes_Evacuacion';
    let textoCriterio = `Para una distancia de observación de <b>${d} metros</b>, la fórmula <i>S &ge; d² / 2000</i> exige un área &ge; <b>${S.toFixed(4)} m²</b> (${Math.round(S_cm)} cm²). `;
    
    if (catSel.includes("Extincion")) {
      textoCriterio += `Equipo contra incendios (NSR-10 Título J): señal cuadrada o rectangular con al menos 50% de color rojo y fotoluminiscencia Clase A (210 mcd/m²). Recomendado: <b>${formatoComercial}</b> fijada a 1.80m y con cuadro de piso de 1.0x1.0m con franjas 45° (Res. 2400/79).`;
    } else if (catSel.includes("Prohibicion")) {
      textoCriterio += `Señal de prohibición (NTC 1461): circular de diámetro &ge; ${D_circular} cm (recomendado &Oslash; ${Math.max(20, D_circular)} cm) con banda roja descendente a 45° cubriendo al menos el 35% de la superficie.`;
    } else if (catSel.includes("Advertencia")) {
      textoCriterio += `Advertencia de peligro (Res. 2400/79): triángulo equilátero con fondo amarillo de seguridad (&ge; 50%) y bordes negros de contraste. Recomendado lado de ${Math.max(20, Math.round((d/35)*100))} cm.`;
    } else {
      textoCriterio += `Rutas de escape y salvamento (ISO 16069): formato rectangular de <b>${formatoAlt.replace('o ', '')}</b> con flecha direccional fotoluminiscente Clase A instalada tanto a 1.70m como a nivel de zócalo (30 cm del piso para visibilidad bajo humo).`;
    }

    if (elGuidance) elGuidance.innerHTML = `💡 <b>Criterio Metrológico Oficial:</b> ${textoCriterio}`;
  }

  slider.addEventListener('input', recalcular);
  if (selectCat) selectCat.addEventListener('change', recalcular);
  if (selectEntorno) selectEntorno.addEventListener('change', recalcular);
  recalcular();
}

// ---------------------------------------------------------
// EXPLORADOR DE FICHAS TÉCNICAS Y CHECKLIST SST
// ---------------------------------------------------------
function setupFichaNormativa() {
  const select = document.getElementById('select-ficha-normativa');
  const container = document.getElementById('ficha-normativa-display');
  if (!select || !container) return;

  function renderFicha() {
    const key = select.value;
    const item = appState.catalogoNormas && appState.catalogoNormas[key] ? appState.catalogoNormas[key] : null;
    if (!item) {
      container.innerHTML = `<p class="text-muted text-sm p-3">Cargando especificaciones normativas de ${key}...</p>`;
      return;
    }

    const catObj = appState.categorias[item.categoria] || {};
    const colorHex = catObj.color_hex || '#3b82f6';

    const checklistHtml = (item.checklist_sst || []).map(c => `
      <div class="checklist-bullet">
        <span class="icon">✓</span>
        <span><b>${c.slice(0, 3)}</b> ${c.slice(3)}</span>
      </div>
    `).join('');

    container.innerHTML = `
      <div class="ficha-layout">
        <div class="ficha-col">
          <div class="ficha-col-title">📐 Especificaciones Dimensionales & Cromáticas</div>
          <div class="ficha-spec-item"><b>Elemento Oficial:</b> ${item.elemento}</div>
          <div class="ficha-spec-item"><b>Categoría SST:</b> <span class="badge" style="background: ${colorHex}22; color: ${colorHex}; border: 1px solid ${colorHex}44;">${item.categoria}</span></div>
          <div class="ficha-spec-item"><b>Norma Reguladora:</b> ${item.norma || 'NTC 1461 / Res. 2400 de 1979'}</div>
          <div class="ficha-spec-item"><b>Colores de Seguridad / Contraste:</b> ${item.color_seguridad || 'Normativo'} / Contraste ${item.color_contraste || 'Blanco'}</div>
          <div class="ficha-spec-item"><b>Forma Geométrica:</b> ${item.forma_geometrica || 'Estandarizada NTC 1461'} (${item.cobertura_min_color || '>= 50%'})</div>
          <div class="ficha-spec-item"><b>Dimensiones según Distancia:</b> ${item.tamano_recomendado || '20x20 cm'} (Fórmula: ${item.formula_dimension || 'S >= d²/2000'})</div>
          <div class="ficha-spec-item"><b>Cota de Montaje:</b> ${item.altura_montaje || '1.60m a 1.80m del NPT'}</div>
          <div class="ficha-spec-item"><b>Demarcación Asociada:</b> ${item.demarcacion_piso || 'Franja amarilla de 10 cm (Res. 2400/79)'}</div>
          <div class="ficha-spec-item"><b>Fotoluminiscencia:</b> ${item.fotoluminiscencia || 'Clase A recomendada para públicas concurrencias'}</div>
        </div>

        <div class="ficha-col">
          <div class="ficha-col-title">📋 Checklist Técnico del Auditor SST ("¿Qué verificar en campo?")</div>
          <div class="ficha-checklist-box">
            ${checklistHtml || '<p class="text-sm text-muted">Realizar verificación visual de estado físico, despeje de 1 metro y ausencia de daños mecánicos.</p>'}
          </div>
          <div class="calc-guidance-note mt-3">
            <b>Recomendación Pericial:</b> ${item.recomendacion}
          </div>
        </div>
      </div>
    `;
  }

  select.addEventListener('change', renderFicha);
  renderFicha();
}
