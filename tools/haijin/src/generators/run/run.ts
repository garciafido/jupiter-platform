import { logger, Tree } from '@nx/devkit';
import { TranscribeGeneratorSchema } from '../transcribe/schema';
import { RunGeneratorSchema } from './schema';
import { userPrompt } from './userPrompts';
import * as path from 'path';
import { NxProjectGit } from '../utils/git-handler';
import * as fs from 'fs-extra';
import transcribe from '../transcribe/transcribe';


export default async function (
  tree: Tree,
  options: RunGeneratorSchema
) {
  await userPrompt(options, tree);
  const directoryPrefix = options.currentServiceType === 'apollo-prisma' ? 'services' : 'apps';

  const projectDir = `${directoryPrefix}/${options.currentService}`;
  const projectRoot = path.join(process.cwd(), projectDir);

  try {
    // 1. Generar el Tree en memoria usando transcribe
    logger.info('Generating project structure in memory...');
    const transcribeOptions: TranscribeGeneratorSchema = {
      name: options.name,
      runOptions: options
    };

    await transcribe(tree, transcribeOptions);
    const changesCount = tree.listChanges().length;
    logger.info(`Generated ${changesCount} files in memory`);

    // 2. Preparar las operaciones Git
    const projectGit = new NxProjectGit(process.cwd(), projectDir);
    const originalBranch = await projectGit.getCurrentBranch();
    logger.info(`Starting Git operations (current branch: ${originalBranch})`);

    let projectExists = false;

    // 3. Cambiar al branch base (donde escribiremos los archivos) y prepararlo
    try {
      // Asegurarse de que las ramas base y develop existen
      await projectGit.ensureBranches();

      // Cambiar a la rama base
      await projectGit.rootGit.git.checkout('base');
      logger.info('Switched to base branch');

      // Verificar si el proyecto ya existe
      projectExists = fs.existsSync(projectRoot);

      if (projectExists) {
        // Preguntar si quiere actualizar el proyecto existente
        const readline = require('readline').createInterface({
          input: process.stdin,
          output: process.stdout
        });

        const answer = await new Promise<string>(resolve => {
          readline.question(`Project ${options.name} already exists. Do you want to update it? (y/N): `, resolve);
        });

        readline.close();

        if (answer.toLowerCase() !== 'y') {
          // Volver al branch original si se cancela
          await projectGit.rootGit.git.checkout(originalBranch);
          logger.info('Update cancelled. Returning to original branch.');
          return;
        }

        logger.info(`Updating ${options.currentService}`);
      } else {
        logger.info(`Creating ${options.currentService}`);
      }

      // Limpiar directorio en base si existe
      try {
        await projectGit.rootGit.git.rm(['-r', `${projectDir}/*`]);
        logger.info('Cleaned existing files in base branch');
      } catch (rmError) {
        if (rmError.message.includes('did not match any files')) {
          logger.info('No existing files to clean in base branch');
        } else {
          throw rmError;
        }
      }

      // 4. IMPORTANTE: Aquí terminamos nuestra preparación
      // NX escribirá automáticamente los archivos en el branch 'base' cuando finalice el generador
      logger.info(`Tree ready. NX will write ${changesCount} files to the base branch upon completion.`);

      // 5. Devolver la función de callback que se ejecutará DESPUÉS de que NX escriba al disco
      return async () => {
        try {
          logger.info('Post-generation operations starting...');

          // 5.1 Git add y commit en branch base
          const action = projectExists ? 'Update' : 'Add';
          await projectGit.addAndCommit(`${action} ${options.currentService} ${options.currentServiceType}: ${options.name}`);
          logger.info(`Changes committed to base branch`);

          // 5.2 Pasar cambios a develop
          let conflictsDetected = false;

          if (projectExists) {
            // Si ya existía, usar patch para aplicar los cambios
            const patchSuccess = await projectGit.patchToDevelop();
            if (!patchSuccess) {
              conflictsDetected = true;
              logger.warn(`
==========================================================================
⚠️ ATENCIÓN: CONFLICTO EN LA APLICACIÓN DEL PARCHE

Se encontraron conflictos al intentar aplicar el parche a la rama develop.
Por favor, sigue las instrucciones anteriores para resolver los conflictos.

Una vez resueltos los conflictos, el proyecto estará actualizado en develop.
Los archivos ya fueron actualizados correctamente en la rama base.
==========================================================================`);
            } else {
              logger.info('Applied patch to develop branch');
            }
          } else {
            // Si es nuevo, usar rebase para sincronizar
            const rebaseSuccess = await projectGit.rebaseToDevelop();

            if (!rebaseSuccess) {
              conflictsDetected = true;
              logger.warn(`
==========================================================================
⚠️ ATENCIÓN: CONFLICTO DE REBASE DETECTADO

Se encontraron conflictos al intentar aplicar los cambios a la rama develop.
Por favor, sigue las instrucciones anteriores para resolver los conflictos.

Una vez resueltos todos los conflictos y completado el rebase, el proyecto
estará actualizado en la rama develop.

Los archivos ya fueron actualizados correctamente en la rama base.
==========================================================================`);
            } else {
              logger.info('Rebased changes to develop branch');
            }
          }

          // 5.3 Volver al branch original solo si no hay conflictos
          if (!conflictsDetected) {
            if (originalBranch && originalBranch !== 'base' && originalBranch !== 'develop') {
              await projectGit.rootGit.git.checkout(originalBranch);
              logger.info(`Returned to original branch: ${originalBranch}`);
            }
          } else {
            // Si hay conflictos, ya estamos en develop donde se necesita resolver
            logger.info('Please resolve conflicts in develop branch');
          }

          const resultAction = projectExists ? 'updated' : 'created';
          logger.info(`✅ ${options.currentService} ${options.currentServiceType} ${options.name} ${resultAction} successfully!`);
        } catch (callbackError) {
          logger.error(`Post-generation operations failed: ${callbackError instanceof Error ? callbackError.message : String(callbackError)}`);

          // Intentar volver al branch original en caso de error grave
          if (originalBranch && originalBranch !== 'base') {
            try {
              await projectGit.rootGit.git.checkout(originalBranch);
              logger.info(`Returned to original branch: ${originalBranch}`);
            } catch (checkoutError) {
              logger.error(`Failed to return to original branch: ${checkoutError.message}`);
            }
          }
        }
      };
    } catch (gitError) {
      // Si falla algo durante las operaciones Git iniciales
      logger.error(`Git operations failed: ${gitError instanceof Error ? gitError.message : String(gitError)}`);

      // Intentar volver al branch original
      if (originalBranch) {
        try {
          await projectGit.rootGit.git.checkout(originalBranch);
          logger.info(`Returned to original branch: ${originalBranch}`);
        } catch (checkoutError) {
          logger.error(`Failed to return to original branch: ${checkoutError.message}`);
        }
      }

      throw new Error(`Failed to prepare Git environment: ${gitError instanceof Error ? gitError.message : String(gitError)}`);
    }
  } catch (error) {
    logger.error(`Project generation failed: ${error instanceof Error ? error.message : String(error)}`);
    throw error;
  }
}
