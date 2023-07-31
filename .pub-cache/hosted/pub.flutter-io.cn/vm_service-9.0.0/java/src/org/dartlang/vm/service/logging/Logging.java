/*
 * Copyright (c) 2014, the Dart project authors.
 *
 * Licensed under the Eclipse Public License v1.0 (the "License"); you may not use this file except
 * in compliance with the License. You may obtain a copy of the License at
 *
 * http://www.eclipse.org/legal/epl-v10.html
 *
 * Unless required by applicable law or agreed to in writing, software distributed under the License
 * is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express
 * or implied. See the License for the specific language governing permissions and limitations under
 * the License.
 */
package org.dartlang.vm.service.logging;

/**
 * {@code Logging} provides a global instance of {@link Logger}.
 */
public class Logging {

  private static Logger logger = Logger.NULL;

  public static Logger getLogger() {
    return logger;
  }

  public static void setLogger(Logger logger) {
    Logging.logger = logger == null ? Logger.NULL : logger;
  }
}
